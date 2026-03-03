import 'dotenv/config';
import app, { port, onServerStarted, setupProcessHandlers, attachWebSocketServers } from './app.js';

const server = app.listen(port, () => {
  Promise.resolve(onServerStarted()).catch((err) => {
    console.error('onServerStarted failed:', err);
  });
});

setupProcessHandlers();
attachWebSocketServers(server);
