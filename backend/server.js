const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'stock-pilot-api' });
});

app.get('/', (req, res) => {
  res.json({ message: 'Stock Pilot API', version: '1.0.0' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`API beží na http://0.0.0.0:${PORT}`);
});
