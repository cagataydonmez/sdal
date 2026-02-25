module.exports = {
  apps: [
    {
      name: 'sdal',
      cwd: '/var/www/sdal',
      script: 'npm',
      args: 'run start',
      env_file: '/etc/sdal/sdal.env',
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
