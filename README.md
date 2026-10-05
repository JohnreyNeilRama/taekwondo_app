# TKD Records

An offline student registry for a Tae-Kwon-Do club: student information sheets,
belt promotions, achievements, ID pictures, a Trash, and a JSON backup for
moving the whole registry to another device.

There is no server and no network at any point. Everything the app saves lives
in one SQLite database on the device, and the security password is checked on
the device itself.

## Where the data lives

- **Android / iOS:** `tkd_app.db` inside the app's databases folder (the folder
  the operating system keeps private to the app).
- **Windows:** `%APPDATA%\tkd_app\tkd_app.db`.

The database holds five tables: `students`, `promotions`, `achievements`,
`attendance` and a
small `app_meta` key/value table. Records are linked by `students.id`, so a
rename can never orphan or duplicate a promotion or an achievement.

Every schema change is **additive**: the database is versioned, and an update
adds the new columns it needs without touching the rows already saved. To add a
future field, raise `AppDatabase._dbVersion` and add an `onUpgrade` branch that
runs `ALTER TABLE ... ADD COLUMN`.

## Security model — read this

- The app asks for a **built-in security password** before it shows the registry.
  The password is verified with PBKDF2-HMAC-SHA256 (120,000 rounds) on the
  device; the password itself is never stored.
- **The password locks the app, it does not encrypt the database file.** The
  database is a normal, unencrypted file. On a phone that is not locked or that
  has been rooted, the file can be read without the password. Keep the phone's
  own lock screen on as the real protection, and keep the device physical.
- Android backup is switched **off** on purpose (`android:allowBackup="false"`):
  the registry holds children's personal details and should not be copied into a
  cloud account silently.
- The exported backup file is also plaintext JSON (pictures included). Keep it
  somewhere you trust, and treat it like the records themselves.

## Attendance (QR check-in)

Every student has a QR code, shown right after they are added and from the QR
button on their details page. It carries only the student's permanent `uid`
(`TKD:<uid>`), so it never changes when the name or registry number does.

The red QR button in the middle of the bottom bar opens the scanner. A scan
writes one row to `attendance` (`student_id`, `attended_on`, `checked_in_at`);
the UNIQUE (student_id, attended_on) rule keeps a second scan on the same day
from counting twice. Where the camera is not available (Windows) or a student
forgot their code, the keyboard button checks in by student number instead.

**Attendance is not part of the JSON backup yet.** Exporting and importing
moves students, pictures, promotions and achievements only, so attendance is
lost if a phone is lost or the registry is restored from a backup.

## Backup and recovery

Recovery depends entirely on **you** exporting a backup file — there is no
automatic copy.

- On the **Data** page, tap **Export backup** and save the `.json` file
  somewhere safe (cloud drive, e-mail to yourself, a USB stick). It contains
  every student, picture, promotion and achievement.
- The app **reminds you** to export: a red card on the Data page and a dot on
  the Data tab whenever there is no backup yet or the last one is more than a
  week old. It never exports automatically.
- To move to a new device: install the app, then **Import backup** with the
  saved file. Importing only ever *adds* records; it never changes or deletes
  what is already on the device, so importing the same file twice is safe.
- If the phone is lost or damaged **without** an exported backup, the records
  cannot be recovered. Export regularly.

Each student carries a random, permanent identity (the `uid` column) so that
importing a backup recognises the same person even after a rename or a
renumbering; this is what keeps a restore from adding a duplicate.

## Releasing the app (do this before the first real install)

1. **Application id.** `android/app/build.gradle.kts` sets
   `applicationId = "com.tkdrecords.app"`. Make sure it is the id you will keep
   forever: changing it later makes the update a *different app* that cannot see
   the records already on the device.
2. **Release keystore.** Create one and keep it safe (losing it means you can no
   longer update the app on a play store listing, and changing it makes the app
   look like a different app). Run this from the project folder; it creates
   `android/tkd-release.jks`:
   ```
   keytool -genkeypair -v -keystore android/tkd-release.jks -alias tkd ^
     -keyalg RSA -keysize 2048 -validity 10000
   ```
   Then create `android/key.properties` (it is git-ignored):
   ```
   storeFile=tkd-release.jks
   storePassword=...
   keyAlias=tkd
   keyPassword=...
   ```
   With that file present, release builds are signed with your key; without it
   they fall back to the debug key (local testing only). Back up the `.jks` file
   and this file, and remember the password — they cannot be replaced.
3. Build with `flutter build apk --release` (or `--appbundle`) and confirm it
   works on a real device.

## Development

```
flutter pub get
flutter analyze
flutter test
flutter run            # or: flutter run -d windows
```

The screens read and write the real database, so the tests open an in-memory
database through the FFI implementation (`sqflite_common_ffi`).

