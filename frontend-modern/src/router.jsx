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
import { applyViewTransitionContext } from './viewTransitions.js';

function supportsViewTransitions() {
  return typeof document !== 'undefined' && typeof document.startViewTransition === 'function';
}

function resolveViewTransitionFlag(requested) {
  if (requested === false) return false;
  return supportsViewTransitions();
}

function isModifiedEvent(event) {
  return Boolean(event.metaKey || event.altKey || event.ctrlKey || event.shiftKey);
}

function shouldPrepareTransition(event, target) {
  if (!event) return true;
  if (event.defaultPrevented) return false;
  if (event.button !== 0) return false;
  if (target && target !== '_self') return false;
  if (isModifiedEvent(event)) return false;
  return true;
}

export const Link = React.forwardRef(function Link({ viewTransition, ...props }, ref) {
  const { onClick, target, to, ...rest } = props;

  function handleClick(event) {
    if (onClick) onClick(event);
    if (resolveViewTransitionFlag(viewTransition) && shouldPrepareTransition(event, target)) {
      applyViewTransitionContext(to);
    }
  }

  return <ReactRouterLink ref={ref} viewTransition={resolveViewTransitionFlag(viewTransition)} onClick={handleClick} target={target} to={to} {...rest} />;
});

export const NavLink = React.forwardRef(function NavLink({ viewTransition, ...props }, ref) {
  const { onClick, target, to, ...rest } = props;

  function handleClick(event) {
    if (onClick) onClick(event);
    if (resolveViewTransitionFlag(viewTransition) && shouldPrepareTransition(event, target)) {
      applyViewTransitionContext(to);
    }
  }

  return <ReactRouterNavLink ref={ref} viewTransition={resolveViewTransitionFlag(viewTransition)} onClick={handleClick} target={target} to={to} {...rest} />;
});

export function useNavigate() {
  const navigate = useReactRouterNavigate();

  return React.useCallback((to, options) => {
    if (typeof to === 'number') return navigate(to);
    if ((options?.viewTransition ?? true) !== false) {
      applyViewTransitionContext(to);
    }
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
