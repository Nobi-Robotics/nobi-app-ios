# Nobi iOS App Update Instructions

## Target firmware

Build/update the iOS app for:

```text
Nobi
Firmware v0.4.0
BLE only
```

This update adds **Nobi Life Mode**, personality stats, petting, sleep/wake, BLE proximity reactions, phone time sync, Pomodoro/focus mode, and a reaction-time mini-game.

Existing features must remain:

```text
BLE connection
16 emotions
text
adjustable text size
notification cards
brightness
128x64 1-bit image transfer
adjustable image scale
status
```

Do not add Wi-Fi UI. The firmware has no Wi-Fi.

---

# 1. BLE identifiers

Advertised name:

```text
Nobi
```

Primary service:

```text
A91E0001-7C1A-4B67-9C53-1B7A6E1F0001
```

Command RX:

```text
A91E0002-7C1A-4B67-9C53-1B7A6E1F0001
```

Device TX:

```text
A91E0003-7C1A-4B67-9C53-1B7A6E1F0001
```

Image RX:

```text
A91E0004-7C1A-4B67-9C53-1B7A6E1F0001
```

Use CoreBluetooth.

Prefer scanning by service UUID.

---

# 2. Core app architecture

Use:

```text
SwiftUI
CoreBluetooth
PhotosUI
CoreGraphics or CoreImage
```

Recommended structure:

```text
Nobi/
├── App/
│   └── NobiApp.swift
│
├── Bluetooth/
│   ├── NobiBLEManager.swift
│   ├── NobiProtocol.swift
│   ├── NobiDeviceState.swift
│   └── NobiProximityMonitor.swift
│
├── Life/
│   ├── NobiLifeState.swift
│   └── NobiTimeSync.swift
│
├── Image/
│   ├── NobiImageConverter.swift
│   └── Dithering.swift
│
├── Views/
│   ├── HomeView.swift
│   ├── LifeView.swift
│   ├── EmotionsView.swift
│   ├── FocusView.swift
│   ├── GamesView.swift
│   ├── TextView.swift
│   ├── ImageView.swift
│   ├── NotificationView.swift
│   └── SettingsView.swift
│
└── Models/
    └── NobiEmotion.swift
```

BLE transport must stay out of SwiftUI view code.

---

# 3. Device state model

The app should maintain a single observable device state.

Suggested fields:

```swift
struct NobiDeviceState {
    var firmwareVersion: String = ""
    var mode: String = "face"
    var emotion: String = "normal"

    var brightness: Int = 180
    var textSize: Int = 2
    var imageScale: Int = 100
    var hasImage: Bool = false

    var lifeModeEnabled: Bool = true
    var sleeping: Bool = false

    var mood: Int = 0
    var energy: Int = 0
    var attention: Int = 0
    var bond: Int = 0

    var proximity: String = "unknown"

    var timeSynced: Bool = false

    var focusActive: Bool = false
    var focusRemainingSeconds: Int = 0

    var gameState: String = "none"
    var lastReactionMs: Int = 0
}
```

---

# 4. Status command

Send:

```text
status
```

Example response:

```text
status|name=Nobi|fw=0.4.0|mode=face|emotion=happy|brightness=180|text_size=2|image_scale=100|image=1|life=1|sleep=0|mood=78|energy=71|attention=66|bond=32|proximity=near|time_synced=1|focus=0|focus_remaining=0|game=none|reaction_ms=243
```

Parse all pipe-separated key/value pairs.

Do not assume field order.

Unknown fields must be ignored instead of breaking parsing.

---

# 5. Life Mode

Life Mode allows Nobi to choose expressions based on:

```text
mood
energy
attention
bond
idle time
local time
phone proximity
```

Enable:

```text
life:on
```

Response:

```text
ok:life:on
```

Disable:

```text
life:off
```

Response:

```text
ok:life:off
```

Read only the personality values:

```text
life:stats
```

Example:

```text
life|mood=78|energy=71|attention=66|bond=32|sleep=0|proximity=near
```

## App UI

Create a dedicated **Nobi** or **Life** screen.

Recommended layout:

```text
Nobi

        [ large Nobi face / OLED-style preview ]

Mood       78
Energy     71
Attention  66
Bond       32

[ Pet Nobi ]

Life Mode              ON
```

Do not make the four values look like medical metrics.

They are playful virtual-pet values.

Use friendly labels and lightweight progress bars.

---

# 6. Pet Nobi

Send:

```text
pet
```

Response:

```text
ok:pet
```

Effects are handled by firmware.

Petting can increase:

```text
mood
attention
bond
```

and produces a happy/heart reaction.

## UI

The main Home screen should have a prominent:

```text
[ Pet Nobi ]
```

button.

Optional visual interaction:

```text
tap Nobi's face preview -> pet
```

Do not spam the command continuously during a long touch.

One deliberate tap should equal one `pet` command.

---

# 7. Sleep / wake

Sleep:

```text
sleep
```

Response:

```text
ok:sleep
```

Wake:

```text
wake
```

Response:

```text
ok:wake
```

The physical BACK button long-press also toggles sleep/wake.

## App UI

Home/Life screen:

```text
[ Sleep Nobi ]
```

or, while asleep:

```text
[ Wake Nobi ]
```

Reflect the real device state returned by `status`.

---

# 8. Time sync

Nobi has no RTC.

The iOS app should send the current Unix timestamp and local timezone offset whenever a connection is established.

Protocol:

```text
time:<unix>|<timezone offset minutes>
```

Example for UTC+05:30:

```text
time:1760000000|330
```

Response:

```text
ok:time
```

Swift concept:

```swift
let unix =
    Int(Date().timeIntervalSince1970)

let seconds =
    TimeZone.current.secondsFromGMT()

let offsetMinutes =
    seconds / 60

sendCommand(
    "time:\(unix)|\(offsetMinutes)"
)
```

Send time:

```text
after BLE connection completes
after TX notifications are subscribed
after phone timezone changes if app is active
```

Do not send every second.

The ESP advances the synchronized Unix time itself using `millis()`.

---

# 9. BLE proximity personality

The ESP32-C3 does not measure phone distance itself in this firmware.

The iOS app estimates near/mid/far from peripheral RSSI.

The app sends only zone changes:

```text
proximity:near
proximity:mid
proximity:far
proximity:unknown
```

Responses:

```text
ok:proximity:near
ok:proximity:mid
ok:proximity:far
ok:proximity:unknown
```

## RSSI sampling

Use:

```swift
peripheral.readRSSI()
```

at a conservative cadence while connected.

Suggested:

```text
every 2 to 4 seconds while app is active
```

Do not sample at high frequency.

BLE RSSI is noisy.

Apply smoothing before classifying.

Example exponential smoothing:

```swift
smoothedRSSI =
    0.75 * oldValue +
    0.25 * newValue
```

## Starting thresholds

Use these only as defaults:

```text
near: >= -58 dBm
mid:  -75 ... -59 dBm
far:  < -75 dBm
```

Add hysteresis so Nobi does not rapidly switch near/mid/near.

For example, require:

```text
2 or 3 consecutive samples
```

before a zone change.

Make thresholds easy to tune in code because enclosure and phone models affect RSSI.

## Important

Do not present RSSI as accurate physical distance.

The UI can say:

```text
Nearby
Around
Far
```

rather than meters.

---

# 10. Pomodoro / focus mode

Start:

```text
pomodoro:start:<minutes>
```

Examples:

```text
pomodoro:start:25
pomodoro:start:50
pomodoro:start:5
```

Accepted range:

```text
1...180 minutes
```

Response:

```text
ok:pomodoro:start:25
```

Stop:

```text
pomodoro:stop
```

Response:

```text
ok:pomodoro:stop
```

Read focus state:

```text
pomodoro:status
```

Example:

```text
pomodoro|active=1|remaining=1244
```

`remaining` is seconds.

When the focus timer ends, Nobi displays:

```text
Focus done!
```

and performs an excited reaction.

## App UI

Create a Focus screen:

```text
Focus with Nobi

25:00

[ 5 ] [ 25 ] [ 50 ]

[ Start Focus ]
```

While active:

```text
23:41

Nobi is focusing with you.

[ Stop ]
```

The phone may run its own local timer for smooth UI animation.

Periodically reconcile with device status rather than writing to the device every second.

---

# 11. Reaction mini-game

Start:

```text
game:reaction
```

Response:

```text
ok:game:reaction
```

Nobi displays:

```text
Wait...
```

After a random delay:

```text
GO!
```

The player presses Nobi's physical ACTION button.

The result appears:

```text
243 ms
```

Pressing too early:

```text
Too soon!
```

Waiting too long:

```text
Too slow!
```

Stop game:

```text
game:stop
```

Response:

```text
ok:game:stop
```

`status` exposes:

```text
game=none
game=wait
game=go
game=result

reaction_ms=<value>
```

## App UI

Create a Games screen.

For v0.4 only one game exists:

```text
Reaction Time

Wait for GO! on Nobi's face,
then press Nobi's Action button.

[ Start Game ]

Best local score: 218 ms
```

Store the best score locally on iPhone.

Do not automatically turn the phone screen into the reaction button; the physical interaction is part of the feature.

---

# 12. Physical button behavior

Current firmware:

```text
LEFT short
previous emotion
also turns Life Mode off for manual emotion control

LEFT hold
brightness down

RIGHT short
next emotion
also turns Life Mode off for manual emotion control

RIGHT hold
brightness up

ACTION short
pet Nobi

ACTION short during reaction game
reaction hit

ACTION hold
start reaction mini-game

BACK short
return to face / leave temporary mode

BACK hold
sleep or wake Nobi
```

The app does not currently receive a dedicated event every time a physical button is pressed.

Do not create UI that assumes button event streaming.

---

# 13. Life Mode vs manual emotions

Manual emotion command:

```text
emotion:happy
```

automatically disables Life Mode.

This is intentional.

If user wants Nobi to resume personality-driven behavior, send:

```text
life:on
```

The app should make this clear.

Example Emotions screen:

```text
Manual Expressions

Choosing an expression pauses Life Mode.

[ Happy ] [ Love ] [ Sleepy ] ...

[ Resume Life Mode ]
```

---

# 14. Existing emotion API

Command:

```text
emotion:<name>
```

Supported:

```text
normal
happy
angry
sad
tired
curious
surprised
love
sleepy
excited
confused
wink
suspicious
scared
bored
smug
```

Response:

```text
ok:emotion:<name>
```

---

# 15. Text

Send:

```text
text:<message>
```

Response:

```text
ok:text
```

Text is temporary and returns to the face after several seconds.

Firmware limits stored text to roughly 100 characters.

Do not assume emoji or arbitrary Unicode render correctly on the OLED.

---

# 16. Adjustable text size

Send:

```text
text_size:1
text_size:2
text_size:3
```

Meanings:

```text
1 small
2 medium
3 large
```

Response:

```text
ok:text_size:<value>
```

Use a segmented control:

```text
Small | Medium | Large
```

---

# 17. Notification cards

Format:

```text
notify:<app>|<title>|<message>
```

Example:

```text
notify:Messages|Alex|Dinner at 8?
```

Response:

```text
ok:notify
```

Invalid:

```text
error:notify_format
```

Do not permit `|` in the three user fields in v0.4.

Important iOS limitation:

A normal third-party iOS app cannot simply inspect arbitrary notifications from every other installed app.

Keep this screen as:

```text
manual notification test
Nobi-app-owned notification display
```

unless a separate supported accessory notification architecture is later implemented.

---

# 18. Brightness

Send:

```text
brightness:<10...255>
```

Example:

```text
brightness:180
```

Response:

```text
ok:brightness:180
```

Throttle slider traffic.

Do not send dozens of writes per second.

---

# 19. Image format

The app converts images before transfer.

Required bitmap:

```text
128 px wide
64 px high
1 bit per pixel
1024 bytes exactly
row-major
16 bytes per row
LSB-first
```

Packing:

```text
byteIndex = y * 16 + x / 8
bitIndex = x % 8

buffer[byteIndex] |= 1 << bitIndex
```

The app should show a true 128×64 monochrome preview generated from the actual transmitted buffer.

---

# 20. Image transfer

Begin:

```text
image_begin
```

Response:

```text
ok:image_begin:1024
```

Send 1024 raw bytes to Image RX.

After receipt:

```text
image_received:1024
```

Then send:

```text
image_end
```

Success:

```text
ok:image:1024
```

Failure:

```text
error:image_size
```

Other commands:

```text
image_show
image_clear
```

Responses:

```text
ok:image_show
ok:image_clear
error:no_image
```

---

# 21. Adjustable image size

Command:

```text
image_scale:<25...200>
```

Examples:

```text
image_scale:50
image_scale:100
image_scale:150
```

Response:

```text
ok:image_scale:<value>
```

Meaning:

```text
<100 = smaller and centered
100  = native 128×64
>100 = zoomed and center-cropped
```

Recommended slider:

```text
25% ---------------- 200%
```

with snap points:

```text
50
75
100
125
150
200
```

---

# 22. Image BLE chunking

Never hardcode a 20-byte chunk size.

Use:

```swift
peripheral.maximumWriteValueLength(
    for: .withoutResponse
)
```

Respect:

```swift
peripheral.canSendWriteWithoutResponse
```

Resume from:

```swift
func peripheralIsReady(
    toSendWriteWithoutResponse peripheral: CBPeripheral
)
```

Using `.withResponse` for image chunks is slower but acceptable for the first reliable implementation.

---

# 23. Home screen redesign

The primary screen should now feel like a virtual companion, not a BLE utility.

Suggested hierarchy:

```text
Nobi                  Connected

        [ OLED-style Nobi face ]

              Happy

Mood        78
Energy      71
Bond        32

          [ Pet Nobi ]

[ Focus ]   [ Play ]   [ Sleep ]

Life Mode                         ON
```

Keep raw connection debugging and UUID information in Settings/Debug only.

---

# 24. Suggested tab/navigation structure

Prefer five primary destinations at most.

Example:

```text
Home
Create
Focus
Play
Settings
```

Where `Create` contains:

```text
Expressions
Text
Image
Notification
```

This is preferable to seven or eight permanent tabs.

---

# 25. Connection sequence

After characteristic discovery:

1. subscribe to TX
2. send `ping`
3. send current `time:<unix>|<timezone>`
4. send `status`
5. begin RSSI monitoring if enabled
6. update UI from device state

Do not send personality settings before TX notifications are ready.

---

# 26. Reconnection

On reconnect:

```text
subscribe TX
sync time
request status
resume RSSI zone monitoring
```

Do not blindly reset mood/bond values from the app.

Firmware is authoritative for current life values while powered.

Image is RAM-only and is lost after device reboot.

The app may offer:

```text
Restore last image after reconnect
```

as an optional preference.

---

# 27. RSSI lifecycle

When connected and app is active:

```text
read RSSI every 2-4 seconds
smooth it
classify zone
send only if zone changes
```

When RSSI cannot be read reliably or app stops monitoring:

```text
proximity:unknown
```

when practical.

Do not make Nobi sad simply because iOS suspended the app.

Treat `unknown` as neutral.

---

# 28. Local app persistence

Store locally:

```text
last connected peripheral UUID
preferred text size
preferred image scale
last selected image
best reaction score
preferred Pomodoro length
proximity monitoring enabled/disabled
```

Do not overwrite device mood, energy, attention, or bond from local app storage.

---

# 29. Nobi protocol constants

Keep BLE constants in one Swift file.

```swift
import CoreBluetooth

enum NobiProtocol {
    static let service = CBUUID(
        string: "A91E0001-7C1A-4B67-9C53-1B7A6E1F0001"
    )

    static let commandRX = CBUUID(
        string: "A91E0002-7C1A-4B67-9C53-1B7A6E1F0001"
    )

    static let tx = CBUUID(
        string: "A91E0003-7C1A-4B67-9C53-1B7A6E1F0001"
    )

    static let imageRX = CBUUID(
        string: "A91E0004-7C1A-4B67-9C53-1B7A6E1F0001"
    )
}
```

---

# 30. Info.plist

Include:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Nobi uses Bluetooth to connect to your companion.</string>
```

Only add Bluetooth background modes if there is a real product requirement and the implementation follows iOS background execution rules.

Do not assume continuous RSSI polling will run indefinitely while the app is suspended.

---

# 31. Visual design direction

Nobi is a physical panda companion.

App aesthetic:

```text
minimal
playful
panda-inspired
monochrome OLED previews
large expressive face preview
soft cards
few controls per screen
no generic BLE-debugger appearance
```

Avoid making mood/energy look clinical.

Avoid gradients unless the product design later explicitly chooses them.

---

# 32. Implementation order for the coding agent

Implement in this order:

1. verify existing BLE connection still works
2. update status parser for v0.4 fields
3. implement time sync
4. Life Mode toggle
5. Life stats UI
6. Pet Nobi
7. Sleep/wake
8. RSSI smoothing and proximity zones
9. Focus/Pomodoro
10. Reaction game UI
11. preserve text/text sizing
12. preserve image transfer/image scaling
13. preserve notification tester
14. reconnect behavior
15. visual polish
16. debug protocol log

Do not rewrite the known-working BLE layer unnecessarily.

---

# 33. Acceptance tests

The update is not complete until these pass on a real iPhone and real Nobi:

```text
[ ] Connects to Nobi
[ ] ping -> pong
[ ] status parses all v0.4 fields
[ ] time sync returns ok:time
[ ] Life Mode can turn on
[ ] Life Mode can turn off
[ ] Pet increases/reacts visibly
[ ] Sleep command produces sleepy face
[ ] Wake command wakes Nobi
[ ] RSSI is smoothed before zone classification
[ ] near/mid/far are not flapping rapidly
[ ] Near transition can trigger Nobi reaction
[ ] Pomodoro starts
[ ] Pomodoro status returns remaining seconds
[ ] Pomodoro stop works
[ ] Focus completion shows Focus done!
[ ] Reaction game starts
[ ] Early press gives Too soon!
[ ] Valid reaction displays milliseconds
[ ] Best score is stored on phone
[ ] All 16 manual emotions still work
[ ] Manual emotion pauses Life Mode
[ ] Resume Life Mode button works
[ ] Text still works
[ ] Small/medium/large text still work
[ ] Image conversion still yields exactly 1024 bytes
[ ] BLE image transfer still works
[ ] Image 25-200% scaling still works
[ ] Brightness still works
[ ] OLED is still SDA GPIO8 / SCL GPIO7
[ ] Physical button short presses work
[ ] Physical button long presses work
[ ] Disconnect/reconnect works
```

---

# 34. Current firmware constraints

v0.4.0 intentionally has:

```text
BLE only
No Wi-Fi
No cloud dependency
No OTA
No IMU
No accelerometer
No microphone
No RTC
Time is synced from iPhone
Proximity is estimated by iPhone BLE RSSI
One 128x64 RAM image at a time
Image is lost after reboot
Four physical buttons
One reaction mini-game
One focus timer
```

Do not invent unsupported capabilities in the app.

---

# 35. Future features - do not implement as if already supported

Possible later additions:

```text
multiple custom animation frames
user-created face packs
persistent life stats in NVS
more mini-games
button-event streaming to app
daily streaks
sound/vibration hardware
battery gauge
ANCS accessory research
```

These are future protocol versions, not v0.4 features.
