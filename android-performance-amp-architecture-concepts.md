# Android Performance & Architecture Concepts

> Reference notes. Original article by Azeem, 30 Aug 2026.
> Written for native Android (Kotlin/Compose); several sections — Compose
> recomposition, WorkManager, R8, DEX, coroutines — do not map directly onto
> this project's React Native app.

## 1. Startup Time
Startup time app launch hone ke moment se lekar user ko usable, interactive UI milne tak ka total time hota hai.

Is duration mein ye operations contribute kar sakte hain:

- Process creation
- Application initialization
- Dependency injection setup
- Database initialization
- Network setup
- First screen composition/rendering
- First meaningful content load

Example: User ne app icon tap kiya aur home screen ko interact karne layak hone mein 1.5 seconds lage. Yeh startup experience ka part hai.

Why it matters: Slow startup directly user experience, perceived app quality, retention, aur conversion ko affect kar sakta hai.

## 2. Cold Start
Cold start tab hota hai jab app ka process device memory mein currently running nahi hota.

Android ko is case mein:

- App process create karna hota hai
- Application initialize karni hoti hai
- Required components load karne hote hain
- Activity/UI create aur render karni hoti hai

Example: Phone restart ke baad Instagram ko pehli baar open karna.

Why it matters: Cold start usually warm aur hot start ke comparison mein expensive hota hai. Production apps startup path ko aggressively optimize karti hain because this is often the slowest launch scenario.

## 3. Warm Start
Warm start mein app ka process memory mein available hota hai, lekin Activity ya UI ko recreate, restore, ya resume karna pad sakta hai.

Example: User app se Home screen par gaya aur kuch seconds baad Recent Apps se app ko wapas open kiya.

Why it matters: Process initialization pehle hi ho chuki hoti hai, isliye warm start generally cold start se faster hota hai.

## 4. ANR
ANR ka full form hai Application Not Responding.

ANR tab trigger ho sakta hai jab Android ko lagta hai ki app required time ke andar user ya system request ka response nahi de rahi. Iska most common reason main thread ko long duration ke liye block kar dena hota hai.

```text
Main Thread
    ↓
5-second database operation
    ↓
UI events process nahi ho rahe
    ↓
ANR
```
Why it matters: Crash ke unlike, app technically running ho sakti hai—but user ke perspective se app completely frozen ya unresponsive hoti hai.

## 5. Jank
Jank ka matlab hai UI frame ka expected deadline miss karna, jiske wajah se scrolling, animation, ya transitions smooth nahi lagte.

60 Hz display par ek frame ko roughly 16.67 ms mein complete hona chahiye. Agar app repeatedly is deadline ko miss kare, user ko stutter, lag, ya skipped frames dikhenge.

Example: RecyclerView ya Compose LazyColumn scroll karte waqt list ka jerk ya skip hona.

Why it matters: App crash nahi kar rahi hoti, lekin experience low-quality aur sluggish feel hota hai.

## 6. Main Thread
Android ka main thread, jise UI thread bhi kaha jata hai, important UI-related work handle karta hai:

- User interactions
- Touch events
- Click handling
- UI updates
- Rendering coordination
- Activity lifecycle callbacks

Is thread par expensive work directly chalana problematic hota hai.

```text
```text
**Bad approach**
- Main Thread
- ↓
- Large database query
- ↓
- UI blocked
```
Better approach
Background Thread
    ↓
Database query
    ↓
Result → Main Thread
```
Network calls, heavy JSON parsing, large database queries, bitmap processing, encryption, aur file I/O ko main thread se avoid karna chahiye.

## 7. Memory Leak
Memory leak tab hota hai jab kisi object ki actual need khatam ho chuki hoti hai, lekin koi active reference us object ko memory mein alive rakhta hai.

Android mein common examples:

- Activity ka reference singleton mein store karna
- Lifecycle incorrectly handle karna
- Listener ya callback unregister na karna
- Long-lived object ke andar short-lived object ka reference rakhna
- Coroutine ya background task ko lifecycle ke baad bhi alive rakhna

Result: App memory gradually increase kar sakti hai aur severe cases mein OutOfMemoryError tak aa sakta hai.

## 8. Battery Drain
Battery drain tab badhta hai jab app unnecessarily CPU, network, GPS, sensors, wake locks, ya background execution use karti hai.

Example: App har 10 seconds mein location update kar rahi hai, even when user actively app use nahi kar raha.

**Better approach**
- Work ko batch karo
- Appropriate scheduling use karo
- Unnecessary background activity avoid karo
- Location updates ki frequency optimize karo
- Network sync ko constraints ke saath run karo
- Foreground service sirf genuinely user-visible ongoing work ke liye use karo

## 9. App Crash
Crash tab hota hai jab application kisi fatal ya unhandled error ki wajah se terminate ho jati hai.

**Common causes:**

- NullPointerException
- Illegal state
- Unhandled coroutine exception
- Memory issues
- Native crashes
- Incorrect lifecycle assumptions
- Invalid cast
- Missing resources or configuration issues

```text
API response
    ↓
Expected user object
    ↓
Object actually null
    ↓
Unhandled exception
    ↓
Crash
```
Production apps mein crash-free users aur crash-free sessions important stability metrics hote hain.

## 10. Background Tasks
Background tasks wo operations hain jo active UI ke directly visible hone ke bina execute karne hote hain.

**Common examples:**

- File upload
- Data synchronization
- Database cleanup
- Periodic sync
- Image processing
- Backup
- Analytics upload
- Notification-related work

Android mein task ke nature ke according different tools use kiye ja sakte hain:

- Coroutines
- WorkManager
- Foreground services
- Alarm-based scheduling in specific cases
- System APIs and job scheduling mechanisms

Important: Wrong scheduler choose karne se battery drain, unreliable execution, duplicate work, ya policy issues ho sakte hain.

## 11. Process Death
Android memory pressure ya system resource management ke time app ka process kill kar sakta hai.

**Important distinction:**

Activity destroy hona aur process death same cheez nahi hai.

Process death ke baad, user app par return kare to app ko important UI state restore karne ke liye prepared hona chahiye.

```text
User fills form
       ↓
App goes to background
       ↓
System kills process
       ↓
User returns
       ↓
App recreated
       ↓
Form state should be restored
```
**Examples of restorable state:**

- Form input
- Selected tab
- Scroll position
- Navigation state
- Draft content
- Filter/sort selection

## 12. Offline Support
Offline support ka matlab hai internet unavailable hone par bhi app ke important features aur previously available data ko usable rakhna.

**Typical architecture:**

```text
UI
 ↓
Repository
 ↓
Local DB / Cache ←→ Remote API
```
App pehle local data show kar sakti hai aur network available hone par server ke saath sync kar sakti hai.

**Benefits:**

- Faster perceived UI
- Better reliability
- Poor network areas mein better usability
- Lower dependency on live API response
- Improved user trust

Yeh offline-first architecture ka foundation ho sakta hai.

## 13. Caching
Caching ka matlab frequently required data ki temporary ya local copy maintain karna hai, taaki same data ko baar-baar expensive source, such as API, database, disk, ya computation se fetch na karna pade.

First request

```text
App → API → Data
             ↓
           Cache
```
Second request

```text
App → Cache → Data
```
**Benefits:**

- Faster UI
- Less network usage
- Better offline experience
- Reduced server requests
- Lower loading time

Caching ka famous challenge hai:

- Cache invalidation: Cached data kab stale ho chuka hai?

Isliye cache ke saath TTL, refresh strategies, versioning, stale-while-revalidate, aur explicit invalidation policies useful hoti hain.

## 14. Pagination
Agar API 100,000 records return karti hai, to sab data ek baar mein download aur render karna inefficient hota hai.

Pagination data ko smaller chunks mein load karti hai.

```text
Page 1 → 20 items
Page 2 → Next 20 items
Page 3 → Next 20 items
...
```
Android mein large lists ke liye Paging-based approaches useful hoti hain.

**Benefits:**

- Lower memory usage
- Faster initial load
- Smaller network response
- Better scrolling performance
- Reduced unnecessary data usage

## 15. API Timeout
Network request theoretically indefinitely wait nahi karni chahiye.

Timeout maximum waiting duration define karta hai.

```text
Request
   ↓
Server
   ↓
No response
   ↓
Timeout
   ↓
Error handling
```
**Common timeout types:**

- Connect timeout: Server se connection establish karne ke liye maximum wait
- Read timeout: Server response read karne ke liye maximum wait
- Write timeout: Request data upload/send karne ke liye maximum wait

Proper timeout handling app ko hanging network requests aur permanently loading UI se bachata hai.

## 16. Retry Logic
Network request fail hone par automatically dobara attempt karna retry logic hai.

Lekin blindly retry karna dangerous ho sakta hai—especially server errors, payment requests, mutations, ya low-network conditions mein.

Good retry strategy mein consider karna chahiye:

- Limited retry attempts
- Exponential backoff
- Retryable vs non-retryable errors
- Network availability
- Idempotency
- Server-provided retry instructions
- Cancellation support

```text
Request failed
    ↓
Wait 1 second
    ↓
Retry
    ↓
Wait 2 seconds
    ↓
Retry
```
Retry typically transient failures—such as temporary network loss or certain server errors—ke liye useful hoti hai, not every error for every API call.

## 17. Race Condition
Race condition tab hoti hai jab multiple threads ya coroutines same shared state ko concurrently access/update karte hain aur final result execution timing par depend karne lagta hai.

Balance = ₹100

Thread A → Reads ₹100
Thread B → Reads ₹100

```text
A → Adds ₹50
B → Subtracts ₹20
```
Expected balance: ₹130
Actual balance: Potentially incorrect, such as ₹80 or ₹150.

Race conditions avoid karne ke liye use kiya ja sakta hai:

- Proper synchronization
- Atomic operations
- Mutex
- Immutable state
- Single-thread ownership
- Database transactions
- Thread-safe collections

## 18. Thread Safety
Code thread-safe tab maana jata hai jab multiple threads simultaneously access karne par bhi shared state inconsistent, corrupted, ya unpredictable na ho.

```text
Thread A ─┐
          ├── Shared Data
Thread B ─┘
```
Agar dono threads ek hi data ko simultaneously modify karein aur synchronization na ho, to race condition create ho sakti hai.

Situation ke according solutions:

- Mutex
- Atomic operations
- synchronized
- Immutable data models
- Single-thread ownership
- Actor-style state handling
- Thread-safe collections

## 19. State Management
State management app ki current information ko store, update, observe, aur UI ke saath synchronize karne ka process hai.

**Examples:**

```text
```text
- Loading
- ↓
- Success
- ↓
- Data displayed
```
isLoggedIn = true
cartItems = 4
selectedTab = "Home"
```
Good state management ensure karta hai:

- Single source of truth
- Predictable state transitions
- UI updates only when required
- Easier debugging
- Better process-death restoration
- Fewer inconsistent UI states

## 20. Lifecycle
Android component ka lifecycle uske different states aur transitions define karta hai.

**Activity lifecycle example:**

```text
onCreate()
   ↓
onStart()
   ↓
onResume()
   ↓
onPause()
   ↓
onStop()
   ↓
onDestroy()
```
Developer ko lifecycle ke according resources acquire aur release karne chahiye.

Example: Camera, location listener, observer, socket, ya coroutine ko unnecessarily Activity lifecycle ke bahar alive rakhna memory leak, resource waste, ya battery drain create kar sakta hai.

## 21. Baseline Profiles
Baseline Profiles Android Runtime ko frequently executed aur important code paths ke baare mein information provide karti hain.

Build/install process ke through yeh information runtime optimization mein help karti hai.

Potential benefits:

- Faster startup
- Faster critical user journeys
- Better runtime performance
- Reduced warm-up cost for important code paths

Production apps mein Baseline Profiles especially valuable hoti hain for startup, login, feed opening, search, checkout, ya other high-traffic flows.

## 22. GC Pressure
GC ka full form Garbage Collection hai. GC unused objects ki memory reclaim karta hai.

Agar app repeatedly bahut saare short-lived objects create karti hai:

```text
Create objects
    ↓
Objects become unused
    ↓
GC
    ↓
Create more objects
    ↓
GC again
```
To GC pressure increase ho sakta hai.

**Impact:**

- Higher CPU usage
- More frequent garbage collection
- Occasional pauses
- Jank in performance-sensitive screens
- Slower scrolling or animation

Performance-critical code paths mein unnecessary allocations avoid karna useful hota hai.

## 23. Main Thread Blocking
Main-thread blocking ka matlab hai main thread ko kisi operation ke complete hone tak wait karwana.

```text
val data = database.query()
```
Agar yeh expensive synchronous database operation UI thread par execute ho raha hai, to UI events delay honge.

**Possible chain:**

```text
Blocking
   ↓
Jank
   ↓
Freeze
   ↓
ANR
```
Isliye expensive work—database, file I/O, network, parsing, image processing, compression—ko appropriate background execution model par shift kiya jata hai.

## 24. Backpressure
Backpressure tab problem banti hai jab producer data ko consumer ki processing speed se faster produce karta hai.

```text
Producer
1000 events/sec
      ↓
Consumer
100 events/sec
```
Consumer eventually overwhelmed ho sakta hai, jiski wajah se memory growth, delayed processing, dropped events, ya UI overload ho sakta hai.

Reactive systems mein common handling strategies:

- Buffering
- Conflation
- Throttling
- Debouncing
- Sampling
- Dropping old events
- Dropping latest events, depending on use case

Example: Search field mein user rapidly type kar raha ho. Har keystroke par API request fire karne ke bajaye debounce use karke request tab bheji ja sakti hai jab user typing pause kare.

## 25. Structured Concurrency
Structured concurrency ka core idea yeh hai ki asynchronous tasks ka lifecycle ek defined scope ke andar ho.

```text
ViewModel Scope
      ↓
Coroutine
   ├── API Call
   └── DB Call
```
Agar ViewModel destroy ho jaye, to us scope se associated work appropriately cancel ho sakta hai.

**Benefits:**

- Orphan coroutines reduce hote hain
- Lifecycle-related bugs reduce hote hain
- Cancellation predictable hoti hai
- Background work controlled rehta hai
- Memory/resource leaks avoid hote hain

## 26. R8
R8 Android build process mein code shrinking, optimization, aur obfuscation ke liye use hota hai.

**R8 typically:**

- Unused code remove karta hai
- Bytecode optimize karta hai
- Class, method, aur field names obfuscate karta hai
- APK/AAB size reduce karne mein help karta hai

Reflection-heavy aur serialization-heavy apps mein correct keep rules important hote hain. Otherwise, release build mein runtime issues aa sakte hain.

## 27. DEX
DEX ka full form hai Dalvik Executable. Yeh Android ka bytecode format hai jise Android Runtime, or ART, execute karta hai.

**Simplified build flow:**

```text
Kotlin / Java
      ↓
Compilation
      ↓
Bytecode
      ↓
DEX
      ↓
Android Runtime (ART)
```
Android application package ke andar DEX files hoti hain, such as:

```text
classes.dex
```
DEX ko samajhna build size, multidex, startup, method count, aur runtime behavior ke context mein useful hota hai.

## 28. Overdraw
Overdraw tab hota hai jab GPU ko same screen pixels ko unnecessarily multiple times draw karna padta hai.

```text
Background
   ↓
Container Background
   ↓
Card Background
   ↓
Child Background
```
Agar multiple overlapping layers visually required nahi hain, to rendering workload unnecessarily increase ho sakta hai.

Overdraw reduce karne ke liye:

- Unnecessary backgrounds remove karo
- UI hierarchy simplify karo
- Redundant containers avoid karo
- Transparent layers ka overuse avoid karo
- Layout aur composable structure inspect karo

## 29. Recomposition
Jetpack Compose mein jab observed state change hoti hai, Compose affected composables ko re-execute karta hai. Is process ko recomposition kehte hain.

**Important point:**

Recomposition khud bad nahi hai.

**Problem tab hoti hai jab:**

- Unnecessary recomposition ho
- Large UI tree repeatedly recompose ho
- Expensive calculations composable body mein repeatedly execute hon
- Unstable parameters unnecessary updates trigger karein
- State incorrectly hoist ya scope ki gayi ho

Good Compose code ka goal recomposition ko completely eliminate karna nahi hai. Goal unnecessary recompositions ko reduce karna aur recomposition ke andar work lightweight rakhna hai.

## 30. WorkManager Constraints
WorkManager mein Constraints define karti hain ki background work execute hone se pehle kaunsi conditions satisfy honi chahiye.

```text
Upload Backup
     ↓
Is Wi-Fi available?
     ↓
Is device charging?
     ↓
YES → Run
NO  → Wait
```
**Common constraints:**

- Network availability
- Charging
- Battery not low
- Storage not low
- Device idle

Constraints use karne se background work battery aur system resources ke according intelligently schedule hota hai.

Example: Large photo backup ko unmetered network aur charging condition ke saath run karna, taaki mobile data aur battery unnecessarily consume na ho.
