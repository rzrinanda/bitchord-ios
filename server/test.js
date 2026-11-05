const http = require('http');

async function get(path, headers = {}) {
  return new Promise((resolve, reject) => {
    http.get({
      host: 'localhost',
      port: 3000,
      path,
      headers
    }, res => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body }));
    }).on('error', reject);
  });
}

async function run() {
  console.log('Testing /health...');
  const health = await get('/health');
  console.log('Health:', health.status, health.body);

  console.log('Testing /manifest.json...');
  const manifest = await get('/manifest.json');
  console.log('Manifest:', manifest.status, manifest.body);

  console.log('Testing /info/UmBNAt4xMSE (Sesi Potret)...');
  const info = await get('/info/UmBNAt4xMSE');
  console.log('Info:', info.status, JSON.parse(info.body).title);

  console.log('Testing stream bytes for /stream/UmBNAt4xMSE with Range: bytes=0-1024...');
  const stream = await get('/stream/UmBNAt4xMSE', { 'Range': 'bytes=0-1024' });
  console.log('Stream status:', stream.status);
  console.log('Content-Type:', stream.headers['content-type']);
  console.log('Content-Range:', stream.headers['content-range']);
  console.log('Content-Length:', stream.headers['content-length']);
  console.log('Bytes received:', stream.body.length);

  if (stream.status === 206 && stream.headers['content-range']) {
    console.log('✅ ALL SERVER TESTS PASSED!');
    process.exit(0);
  } else {
    console.error('❌ Stream test failed');
    process.exit(1);
  }
}

run().catch(err => {
  console.error(err);
  process.exit(1);
});
