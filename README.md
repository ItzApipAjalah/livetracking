# Live Tracking with Flutter

A Flutter application for live tracking, which sends location data to an API. This project demonstrates how to get real-time location updates and send them to a backend server for further processing.

## Features

- Real-time location tracking
- Sending location data to a REST API
- Displaying location on a map


![Example UI](https://i.ibb.co/wNKVT7X/example.png)

## Getting Started

### Prerequisites

- [Flutter](https://flutter.dev/docs/get-started/install) (latest stable version)
- A running instance of the backend API (example provided below)

### Installation

1. **Clone the repository:**
    ```bash
    git clone https://github.com/ItzApipAjalah/livetracking.git
    cd livetracking
    ```

2. **Install dependencies:**
    ```bash
    flutter pub get
    ```

3. **Run the app:**
    ```bash
    flutter run
    ```

## API Endpoint

The application sends location data to a specified API endpoint. Here is an example of what the API might look like.

### Example API (Node.js + Express)

**Install dependencies:**
```bash
npm install express sequelize mysql2 body-parser
```

**Configuration:**
Create a file `config/database.js`:

```js
const { Sequelize } = require('sequelize');

const sequelize = new Sequelize('databasee', 'table', 'password', {
    host: 'HOST',
    dialect: 'mysql'
});

module.exports = sequelize;
```

**Model:**
Create a file `models/Map.js`:

```js
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Map = sequelize.define('Map', {
    maps_url: {
        type: DataTypes.STRING,
        allowNull: false
    },
    date_upload: {
        type: DataTypes.DATE,
        defaultValue: DataTypes.NOW
    }
}, {
    timestamps: true
});

module.exports = Map;
```

**Controller:**
Create a file `controllers/mapsController.js`:

```js
const Map = require('../models/Map');

exports.upload = async (req, res) => {
    const { maps_url } = req.body;

    if (!maps_url) {
        return res.status(400).json({ message: 'maps_url is required' });
    }

    try {
        // Hapus data lama
        await Map.destroy({ where: {} });

        // Buat data baru
        const map = await Map.create({ maps_url });

        res.status(200).json({ message: 'Data successfully uploaded', map });
    } catch (error) {
        res.status(500).json({ message: 'Error uploading data', error });
    }
};

exports.get = async (req, res) => {
    try {
        const map = await Map.findOne({
            order: [['createdAt', 'DESC']]
        });

        if (!map) {
            return res.status(404).json({ message: 'No data available' });
        }

        res.status(200).json(map);
    } catch (error) {
        res.status(500).json({ message: 'Error fetching data', error });
    }
};
```

**Routes:**
Create a file `routes/maps.js`:

```js
const express = require('express');
const router = express.Router();
const mapsController = require('../controllers/mapsController');

router.post('/upload', mapsController.upload);
router.get('/', mapsController.get);

module.exports = router;
```

**Server Initialization:**
Create a file `index.js`:

```js
const express = require('express');
const bodyParser = require('body-parser');
const sequelize = require('./config/database');
const mapsRoutes = require('./routes/maps');

const app = express();
app.use(bodyParser.json());
app.use('/maps', mapsRoutes);

app.get('/', (req, res) => {
    res.redirect('/maps');
});

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});

```

## Displaying the Location on a Map

To display the location on a map, you can use the following HTML and JavaScript code:

**HTML**

```html
<div id="location-map" style="width: 100%; height: 300px;">
    <div class="overlay-text">My Current Location</div>
</div>

```

**Java Script**

```js
function fetchLocationAndUpdateMap() {
  fetch('http://localhost:3000/maps')
      .then(response => response.json())
      .then(data => {
          // Extract coordinates from the maps_url
          const mapsUrl = data.maps_url;
          const coordinates = mapsUrl.match(/q=([-0-9.]+),([-0-9.]+)/);
          const latitude = parseFloat(coordinates[1]);
          const longitude = parseFloat(coordinates[2]);
          
          // Generate Google Maps embed URL
          const mapEmbedUrl = `https://www.google.com/maps?q=${latitude},${longitude}&output=embed`;

          // Update the location-map div with embedded map
          document.getElementById('location-map').innerHTML += `<iframe frameborder="0" style="border:0;" allowfullscreen loading="lazy" src="${mapEmbedUrl}"></iframe>`;
      })
      .catch(error => console.error('Error fetching location data:', error));
}

fetchLocationAndUpdateMap();

setInterval(fetchLocationAndUpdateMap, 60000); 

```

**Results**

![Example Html](https://i.ibb.co.com/pjJzzWH/examplehtml.png)