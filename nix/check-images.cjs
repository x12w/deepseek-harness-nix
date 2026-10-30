// Decode and transform images in the installed Desktop Host's Electron runtime.
const assert = require('node:assert/strict');
const { createRequire } = require('node:module');
const requireRuntime = createRequire(`${process.argv[2]}/package.json`);
const sharp = requireRuntime('sharp');

const deadline = setTimeout(() => {
  console.error('Image processing smoke check timed out');
  process.exit(1);
}, 30000);

async function checkImages() {
  const input = await sharp({
    create: { width: 64, height: 48, channels: 3, background: '#336699' },
  }).png().toBuffer();
  // Reading metadata reproduces the prebuilt sharp/Electron GLib crash.
  const metadata = await sharp(input).metadata();
  assert.equal(metadata.width, 64);
  assert.equal(metadata.height, 48);
  assert.equal(metadata.format, 'png');

  await Promise.all(['png', 'jpeg', 'webp'].map(async (format) => {
    const output = await sharp(input).resize(32, 24).toFormat(format).toBuffer();
    const decoded = await sharp(output).raw().toBuffer({ resolveWithObject: true });
    assert.equal(decoded.info.width, 32);
    assert.equal(decoded.info.height, 24);
    assert.equal(decoded.data.length, 32 * 24 * decoded.info.channels);
  }));
  await assert.rejects(sharp(Buffer.from('invalid image')).metadata(), /unsupported image format/);
  console.log('Image metadata, resize, PNG/JPEG/WebP, and invalid input smoke checks passed');
}

checkImages().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}).finally(() => clearTimeout(deadline));
