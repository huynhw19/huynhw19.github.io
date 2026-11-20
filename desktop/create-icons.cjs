const fs = require('node:fs/promises');
const path = require('node:path');
const sharp = require('sharp');
const pngToIco = require('png-to-ico');

async function main() {
  const root = path.join(__dirname, '..');
  const buildDir = path.join(root, 'build');
  await fs.mkdir(buildDir, { recursive: true });
  const svg = await fs.readFile(path.join(root, 'configkit-oauth-logo.svg'));
  const macPngPath = path.join(buildDir, 'icon.png');
  await sharp(svg).resize(1024, 1024).png().toFile(macPngPath);
  const windowsPng = await sharp(svg).resize(256, 256).png().toBuffer();
  const ico = await pngToIco([windowsPng]);
  await fs.writeFile(path.join(buildDir, 'icon.ico'), ico);
  console.log('Generated 1024px macOS/Linux icon and Windows ICO.');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
