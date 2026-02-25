module.exports = {
  apps: [
    {
      name: 'sdal',
      cwd: '/var/www/sdal',
      script: '/var/www/sdal/ops/start-sdal.sh',
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      watch: false,
      max_memory_restart: '700M',
      env: {
        NODE_ENV: 'production'
      }
    }
  ]
};
