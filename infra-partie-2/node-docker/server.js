const express = require('express');
const app = express();
const PORT = 3000;

app.get('/', (req, res) => {
  res.send("Hello Badr from Docker version 1.1 !");
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
