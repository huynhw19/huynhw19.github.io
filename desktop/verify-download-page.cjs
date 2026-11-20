const fs = require('node:fs');
const assert = require('node:assert/strict');
const html = fs.readFileSync('downloads.html', 'utf8');
const guide = fs.readFileSync('PLATFORM-INSTALL.md', 'utf8');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
const androidManifest = fs.readFileSync('android/app/src/main/AndroidManifest.xml', 'utf8');
const androidSource = fs.readFileSync('android/app/src/main/java/com/configkit/android/MainActivity.java', 'utf8');
const builder = fs.readFileSync('mobileconfig-builder.html', 'utf8');
const expectedLinks = ['ConfigKit-Windows-Setup.exe','ConfigKit-macOS-arm64.dmg','ConfigKit-macOS-x64.dmg','ConfigKit-Linux-x64.AppImage','ConfigKit-Android.apk'];
for (const asset of expectedLinks) {
  assert.ok(html.includes('/releases/latest/download/' + asset), 'Missing direct download link: ' + asset);
  assert.ok(guide.includes(asset), 'Missing install documentation for: ' + asset);
}
for (const platform of ['Windows','macOS','Linux','Android','iPhone','iPad'])
  assert.ok(html.includes(platform), 'Missing platform card or instructions: ' + platform);
assert.ok(fs.existsSync('mobileconfig-builder.html'), 'iOS profile builder page is missing');
assert.ok(builder.includes('application/x-apple-aspen-config'), 'Profile builder MIME type is missing');
assert.ok(builder.includes('URL.createObjectURL'), 'Profile builder local download is missing');
assert.equal(pkg.build.mac.icon, 'build/icon.png', 'macOS icon must use the high-resolution PNG');
assert.ok(androidManifest.includes('android.permission.INTERNET'), 'Android app needs internet permission');
assert.ok(androidManifest.includes('@mipmap/ic_launcher'), 'Android launcher icon is not configured');
assert.ok(fs.existsSync('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml'), 'Android adaptive launcher icon is missing');
assert.ok(fs.existsSync('android/app/src/main/res/drawable/ic_launcher_foreground.xml'), 'Android launcher foreground icon is missing');
assert.ok(androidSource.includes('saveBase64') && androidSource.includes('ACTION_CREATE_DOCUMENT'), 'Android app must save generated profile downloads');
assert.ok(androidSource.includes('onShowFileChooser'), 'Android app must support file selection');
assert.ok(pkg.scripts['dist:win'] && pkg.scripts['dist:mac'] && pkg.scripts['dist:linux'], 'Missing desktop build scripts');
console.log('PASS: ConfigKit platform links, install docs, iOS profile generation, Android file upload/download and desktop scripts.');
