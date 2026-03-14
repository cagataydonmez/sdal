import React from 'react';
import {
  createBrowserRouter,
  createRoutesFromElements,
  Link as ReactRouterLink,
  NavLink as ReactRouterNavLink,
  Navigate,
  Outlet,
  Route,
  RouterProvider,
  useLocation,
  useNavigate as useReactRouterNavigate,
  useParams,
  useSearchParams
} from 'react-router-dom';

function supportsViewTransitions() {
  return typeof document !== 'undefined' && typeof document.startViewTransition === 'function';
}

function resolveViewTransitionFlag(requested) {
  if (requested === false) return false;
  return supportsViewTransitions();
}

export const Link = React.forwardRef(function Link({ viewTransition, ...props }, ref) {
  return <ReactRouterLink ref={ref} viewTransition={resolveViewTransitionFlag(viewTransition)} {...props} />;
});

export const NavLink = React.forwardRef(function NavLink({ viewTransition, ...props }, ref) {
  return <ReactRouterNavLink ref={ref} viewTransition={resolveViewTransitionFlag(viewTransition)} {...props} />;
});

export function useNavigate() {
  const navigate = useReactRouterNavigate();

  return React.useCallback((to, options) => {
    if (typeof to === 'number') return navigate(to);
    if (options && Object.prototype.hasOwnProperty.call(options, 'viewTransition')) {
      return navigate(to, options);
    }
    return navigate(to, {
      ...(options || {}),
      viewTransition: supportsViewTransitions()
    });
  }, [navigate]);
}

export {
  createBrowserRouter,
  createRoutesFromElements,
  Navigate,
  Outlet,
  Route,
  RouterProvider,
  useLocation,
  useParams,
  useSearchParams
};
