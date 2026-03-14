import React from 'react';
import { createRoot } from 'react-dom/client';
import { createBrowserRouter, RouterProvider } from './router.jsx';
import { appRoutes } from './App.jsx';
import './styles.css';

const router = createBrowserRouter(appRoutes);

createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <RouterProvider router={router} />
  </React.StrictMode>
);
