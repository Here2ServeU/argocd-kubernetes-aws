const express = require('express');
const app = express();
const port = 3000;

app.get('/', (req, res) => {
  res.send('Salut, World, from Dr. Emmanuel here at T2S!');
});

app.listen(port, () => {
  console.log(`Server is running on http://localhost:${port}`);
});
