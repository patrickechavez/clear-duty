# ClearDuty

An alcohol testing kiosk for public utility vehicle drivers, run on an iPad
mounted at the depot. A driver holds their ID up to the camera, a supervisor
confirms the face matches, the driver blows, and the terminal says whether they
are cleared to drive.

iOS 17+ · Swift 6 strict concurrency · SwiftUI · Supabase

**Working.** Card scanning, employee lookup, the supervised confirm step, the
blow reported stage by stage, face presence gating the start, a photo taken
mid-blow, and every refusal and cancellation path.

**Simulated.** The breath analyser, behind the same protocol a real one would
sit behind. See [No vendor SDK](#no-vendor-sdk-is-linked).

**Not built.** Persistence. Nothing is written down yet, so the tally on the
idle screen stays at zero.

## Try it

No account, no server, no device.

1. Clone and open `ClearDuty.xcodeproj`
2. Pick the **Demo** scheme
3. Run on any iPad simulator
4. Tap **Continue as demo supervisor**

The demo runs on mock data alone: no network, no Supabase, no keychain, no
Firebase. A simulator has no camera, so the idle screen offers four cards
instead of the reader, one per outcome:

| Card | Code | What happens |
| --- | --- | --- |
| Active driver | `CARD-4F2A91` | Confirm screen, then the blow, then a verdict |
| Suspended driver | `CARD-0FA983` | Refused with "Not cleared to test" |
| Staff card | `CARD-S014` | Refused the same way, on purpose |
| Unknown card | `CARD-NOTREAL` | "Card not recognised" |

Scanning a real code, face presence and the photo need the iPad. Everything
demo-only is compiled out of Staging and Production.

## Test it with the camera

This is the half a simulator cannot show: reading the card, waiting for a face,
and the photo taken mid-blow. It needs an iPad, since the iPhone build only
shows the dispatcher board placeholder.

1. Run the **Development** scheme on an iPad
2. Sign in with `kiosk.cubao@clearduty.test`, password the same
3. Hold a card up to the camera, printed or shown on a second screen

The cards are the same four as above:
[active driver](.github/assets/card-active-driver.png),
[suspended driver](.github/assets/card-suspended-driver.png),
[staff](.github/assets/card-staff.png),
[unknown](.github/assets/card-unknown.png).

Hold the QR side towards the screen, about 20 cm away. Once a driver is
confirmed, step into frame: the blow will not start until the camera sees a
face.

## How a test runs

1. **Idle.** The camera watches for a card.
2. **Scan.** A QR or Code 128 card code is read once, then ignored for five
   seconds so one card held up does not scan repeatedly.
3. **Lookup.** The code resolves to an employee row, or to why it was refused.
4. **Confirm.** A supervisor checks the face against the stored photo and taps
   through. Drivers have no login and are not meant to have one: they are
   identified by the card and the person standing next to them.
5. **Presence.** The blow does not start until a face is in frame.
6. **Blow.** Warming up, blow now, keep blowing, analysing, one screen each.
7. **Photo.** A still is taken mid-blow, while the driver is at the analyser.
8. **Verdict.** Cleared, not cleared, or invalid. Six seconds, then idle.

A card that is unknown, suspended or staff never reaches step 4. A driver who
walks away before the sample is captured stops the test at step 6.

## Decisions worth explaining

### No vendor SDK is linked

BACtrack publishes an iOS SDK. It is deliberately absent.

An integration that has never run against hardware is unverified code that
looks finished, and vendor SDKs are usually keyed to a developer account and
restricted in how they may be redistributed. Neither belongs in a public
repository. Keeping the seam empty also means every screen builds and tests
with no device:

```swift
protocol BreathAnalyzer: Sendable {
    var serial: String { get }
    var calibrationExpiresOn: Date { get }
    var isConnected: Bool { get }
    func measure() -> AsyncThrowingStream<BlowStage, any Error>
}
```

A reading arrives as a stream of stages rather than one number, because the
kiosk has to tell the driver what to do at each one. A real device would bridge
its delegate callbacks into the same stream.

Their SDK reports the serial, the battery level, and `BacTrackUseCount`, how
many tests the unit has taken. It reports nothing about calibration, which is
why `serial` comes from the device while `calibrationExpiresOn` comes from the
operator's records. Calibration is due every twelve months or after so many
tests, whichever lands first, so a real terminal would warn on the count the
device reports and on a date it was told. Servicing means posting the unit away
for ten to fourteen business days, so a depot that blocks shifts on a failed
test needs two analysers, not one.

### A test with nobody in front of the camera is not evidence

The blow is gated on a face being in frame, and if the driver leaves before the
sample is captured the test is stopped. Once the analyser reaches `analysing`
the sample already exists, so walking away no longer invalidates it.

Detection costs nothing extra: the metadata output already reading QR codes
also reports faces, so there is no second video output and no Vision request
per frame. Faces are reported as they appear rather than as an empty frame, so
`PresenceClock` turns "last seen at" into a reading four times a second.

A cancelled attempt is recorded as invalid rather than discarded, which is what
makes repeated abandonment visible. A confirmed driver who never steps in front
of the camera gives up after twenty seconds rather than holding the terminal.

### Refusals do not explain themselves

A suspended driver and a staff card produce the same message. A mounted screen
in a depot is semi-public, so it does not announce why someone was refused.
The same reasoning keeps a failed test stated plainly instead of shouted.

### The threshold is zero

Public utility drivers get no allowance. It is snapshotted onto every test
rather than read at display time, so a later policy change cannot rewrite what
a past test meant.

## What's inside

- **Networking** one send path with verb helpers, typed errors, interceptors, retry with backoff
- **Auth** access and refresh tokens, single-flight refresh, 401 to refresh to retry to sign-out, Keychain storage
- **Navigation** typed routes, deep links, force-update and maintenance gates driven by HTTP status
- **Hardware** analyser, presence and photo capture behind protocols, with simulators for each
- **UI** design system, `LoadState`, empty and error states, localization via String Catalog
- **Observability** analytics and crash reporting behind protocols, Firebase adapters optional
- **Hardening** certificate pinning, a privacy shield over the app switcher, report-only jailbreak and debugger checks
- **Build** three environments plus a demo scheme, privacy manifest

## Architecture

```
View (SwiftUI, no logic)
  ↕ @Observable
ViewModel (@MainActor, owns the phase machine)
  ↕ protocol
Repository / Hardware
  ↕ protocol
APIClient (one send path + interceptors) / AVFoundation
```

Each layer depends on the protocol below it. `AppDependencies` is the one place
concrete types meet, which is what lets the Demo scheme swap the whole bottom
half for mocks.

## Structure

```
ClearDuty/
├── App/              entry point, composition root, environments
├── Components/       reusable inputs and buttons
├── Core/
│   ├── Hardware/     analyser, presence, photo capture, the camera session
│   ├── Networking/   client, endpoints, errors, interceptors
│   ├── Security/     pinning, privacy shield, jailbreak and debugger checks
│   ├── Session/      tokens, refresh, session state
│   └── Testing/      sample data and mocks, Development builds only
├── Data/             repositories
├── DesignSystem/     theme, accessibility identifiers
├── Features/
│   ├── Auth/         sign in
│   └── Kiosk/        the terminal: idle, confirm, blow, result
└── Resources/        String Catalog
```

## Pointing it at your own Supabase

Only needed to run it against your own data rather than the test account above.

- An `employees` table with `card_code`, `employee_no`, `first_name`,
  `last_name`, `role` and `status`, plus an auth user for the supervisor. The
  schema is not in this repo.
- `API_BASE_URL` in `Config/Development.xcconfig`, pointed at your project.
- `Config/Secrets.xcconfig`, copied from the example, holding the anon key.
  Gitignored. The `service_role` key must never reach a client, since it
  bypasses every row level security policy you wrote.
- The Development scheme, on an iPad. A simulator cannot scan a card, find a
  face or take a photo.
