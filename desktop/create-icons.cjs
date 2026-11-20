const fs = require('node:fs/promises');
const path = require('node:path');
const sharp = require('sharp');
const pngToIco = require('png-to-ico');

async function main() {
  const root = path.join(__dirname, '..');
  const buildDir = path.join(root, 'build');
  await fs.mkdir(buildDir, { recursive: true });
  const svg = await fs.readFile(path.join(root, 'configkit-oauth-logo.svg'));
  const pngPath = path.join(buildDir, 'icon.png');
  const icoPath = path.join(buildDir, 'icon.ico');
  await sharp(svg).resize(256, 256).png().toFile(pngPath);
  const ico = await pngToIco(pngPath);
  await fs.writeFile(icoPath, ico);
  console.log('Generated ConfigKit Windows app icons.');
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
