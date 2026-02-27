const http = require('http');
const https = require('https');

const PORT = process.env.PORT || 3000;
const AWS_REGION = process.env.AWS_REGION || 'eu-west-2';
const DB_HOST = process.env.DB_HOST || 'localhost';

// Simple health check server
const server = http.createServer((req, res) => {
  // Health endpoint
  if (req.url === '/health' && req.method === 'GET') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      region: AWS_REGION,
      database: DB_HOST ? 'configured' : 'not configured'
    }));
    return;
  }

  // Root endpoint
  if (req.url === '/' && req.method === 'GET') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      service: 'Healthcare DR Application',
      version: '1.0.0',
      region: AWS_REGION,
      environment: process.env.NODE_ENV || 'development'
    }));
    return;
  }

  // API info endpoint
  if (req.url === '/api/info' && req.method === 'GET') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      application: 'Healthcare DR',
      description: 'Multi-region disaster recovery solution',
      endpoints: {
        health: '/health',
        info: '/api/info',
        status: '/api/status'
      }
    }));
    return;
  }

  // Status endpoint with DR info
  if (req.url === '/api/status' && req.method === 'GET') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: 'operational',
      region: AWS_REGION,
      database: {
        host: DB_HOST,
        status: 'connected'
      },
      disaster_recovery: {
        strategy: 'Pilot Light',
        rto_target: '15-30 minutes',
        rpo_target: '< 1 hour'
      },
      timestamp: new Date().toISOString()
    }));
    return;
  }

  // 404 for other routes
  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Not found' }));
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Healthcare DR app listening on port ${PORT}`);
  console.log(`Region: ${AWS_REGION}`);
  console.log(`Database Host: ${DB_HOST}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});