/**
 * Healthcare Application Server
 * A simple Express.js application for healthcare DR demonstration
 */

const express = require('express');
const { createClient } = require('@aws-sdk/client-secrets-manager');
const mysql = require('mysql2/promise');

const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Request logging
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} ${req.method} ${req.path}`);
  next();
});

// Database connection pool
let dbPool = null;

/**
 * Get database credentials from Secrets Manager
 */
async function getDbCredentials() {
  if (!process.env.DB_SECRET_ARN) {
    return {
      host: process.env.DB_HOST || 'localhost',
      user: process.env.DB_USER || 'admin',
      password: process.env.DB_PASSWORD || 'password',
      database: process.env.DB_NAME || 'healthcare'
    };
  }

  const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');
  const client = new SecretsManagerClient({ region: process.env.AWS_REGION || 'eu-west-2' });
  
  const response = await client.send(
    new GetSecretValueCommand({ SecretId: process.env.DB_SECRET_ARN })
  );
  
  const secret = JSON.parse(response.SecretString);
  return {
    host: process.env.DB_HOST,
    user: secret.username,
    password: secret.password,
    database: secret.database || 'healthcare'
  };
}

/**
 * Initialize database connection
 */
async function initDatabase() {
  try {
    const credentials = await getDbCredentials();
    dbPool = mysql.createPool({
      ...credentials,
      waitForConnections: true,
      connectionLimit: 10,
      queueLimit: 0
    });
    console.log('Database connection pool initialized');
  } catch (error) {
    console.error('Failed to initialize database:', error.message);
  }
}

// Health check endpoint
app.get('/health', async (req, res) => {
  const health = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: process.env.APP_VERSION || '1.0.0',
    region: process.env.AWS_REGION || 'unknown',
    checks: {
      server: 'ok',
      database: 'unknown'
    }
  };

  try {
    if (dbPool) {
      const [rows] = await dbPool.query('SELECT 1');
      health.checks.database = 'ok';
    } else {
      health.checks.database = 'not_configured';
    }
  } catch (error) {
    health.checks.database = 'error';
    health.status = 'degraded';
  }

  const statusCode = health.status === 'healthy' ? 200 : 503;
  res.status(statusCode).json(health);
});

// Readiness check
app.get('/ready', async (req, res) => {
  try {
    if (dbPool) {
      await dbPool.query('SELECT 1');
    }
    res.status(200).json({ ready: true });
  } catch (error) {
    res.status(503).json({ ready: false, error: error.message });
  }
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    name: 'Healthcare DR Application',
    version: process.env.APP_VERSION || '1.0.0',
    environment: process.env.NODE_ENV || 'development',
    region: process.env.AWS_REGION || 'unknown'
  });
});

// API: Get patients (example endpoint)
app.get('/api/patients', async (req, res) => {
  try {
    if (!dbPool) {
      return res.status(503).json({ error: 'Database not available' });
    }
    const [rows] = await dbPool.query('SELECT id, name, created_at FROM patients LIMIT 100');
    res.json({ patients: rows });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// API: Create patient (example endpoint)
app.post('/api/patients', async (req, res) => {
  try {
    if (!dbPool) {
      return res.status(503).json({ error: 'Database not available' });
    }
    const { name, email } = req.body;
    const [result] = await dbPool.query(
      'INSERT INTO patients (name, email) VALUES (?, ?)',
      [name, email]
    );
    res.status(201).json({ id: result.insertId, name, email });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// Start server
app.listen(port, async () => {
  console.log(`Healthcare app listening on port ${port}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Region: ${process.env.AWS_REGION || 'unknown'}`);
  
  await initDatabase();
});

module.exports = app;
