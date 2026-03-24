import React, { useMemo, useState } from 'react';
import { motion } from 'motion/react';

function mergeClassName(...parts) {
  return parts.filter(Boolean).join(' ');
}

function iconPrimitives(name, active) {
  switch (name) {
    case 'menu':
      return [
        { key: 'top', type: 'line', x1: 4, y1: 7, x2: 20, y2: 7, variant: 'line-slide', animate: { x1: [6, 4], x2: [18, 20] } },
        { key: 'mid', type: 'line', x1: 4, y1: 12, x2: 20, y2: 12, variant: 'line-slide', animate: { x1: [3, 4], x2: [21, 20] } },
        { key: 'bottom', type: 'line', x1: 4, y1: 17, x2: 20, y2: 17, variant: 'line-slide', animate: { x1: [6, 4], x2: [18, 20] } }
      ];
    case 'home':
      return [
        { key: 'roof', type: 'path', d: 'M3 10.4 12 3l9 7.4', variant: 'draw', animate: { pathLength: [0.2, 1], opacity: [0.4, 1] } },
        { key: 'body', type: 'path', d: 'M6 10v10h12V10', variant: 'draw', animate: { pathLength: [0.35, 1], opacity: [0.6, 1] } },
        { key: 'door', type: 'path', d: 'M10 20v-5a2 2 0 0 1 4 0v5', variant: 'door', animate: { scaleY: [0.85, 1], opacity: [0.4, 1] } }
      ];
    case 'users':
      return [
        { key: 'left-head', type: 'circle', cx: 8, cy: 9, r: 2.75, variant: 'pop', animate: { scale: [0.72, 1] } },
        { key: 'right-head', type: 'circle', cx: 16, cy: 9, r: 2.75, variant: 'pop', animate: { scale: [0.72, 1], transition: { delay: 0.05 } } },
        { key: 'left-body', type: 'path', d: 'M3.8 19c.9-2.6 2.8-3.9 4.2-3.9', variant: 'draw', animate: { pathLength: [0.15, 1], opacity: [0.35, 1] } },
        { key: 'right-body', type: 'path', d: 'M20.2 19c-.9-2.6-2.8-3.9-4.2-3.9', variant: 'draw', animate: { pathLength: [0.15, 1], opacity: [0.35, 1], transition: { delay: 0.05 } } },
        { key: 'center-body', type: 'path', d: 'M8.8 18.2c.9-2.2 2-3.2 3.2-3.2s2.3 1 3.2 3.2', variant: 'draw', animate: { pathLength: [0.15, 1], opacity: [0.35, 1], transition: { delay: 0.1 } } }
      ];
    case 'calendar':
      return [
        { key: 'frame', type: 'rect', x: 3, y: 4.5, width: 18, height: 16.5, rx: 2.4, variant: 'draw', animate: { pathLength: [0.2, 1], opacity: [0.45, 1] } },
        { key: 'line', type: 'path', d: 'M3 10.5h18', variant: 'draw', animate: { pathLength: [0.15, 1], opacity: [0.35, 1], transition: { delay: 0.05 } } },
        { key: 'left-pin', type: 'path', d: 'M8 2.8v4.4', variant: 'lift', animate: { y: [-0.4, 0.4, 0] } },
        { key: 'right-pin', type: 'path', d: 'M16 2.8v4.4', variant: 'lift', animate: { y: [0.4, -0.4, 0], transition: { delay: 0.05 } } }
      ];
    case 'bell':
      return [
        { key: 'shell', type: 'path', d: 'M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9', variant: 'swing', animate: { rotate: [-8, 8, -4, 0] } },
        { key: 'clapper', type: 'path', d: 'M10.4 20.8a1.85 1.85 0 0 0 3.2 0', variant: 'fade', animate: { opacity: [0.45, 1], scale: [0.88, 1] } }
      ];
    case 'badge-alert':
      return [
        { key: 'burst', type: 'path', d: 'M3.85 8.62a4 4 0 0 1 4.78-4.77 4 4 0 0 1 6.74 0 4 4 0 0 1 4.78 4.78 4 4 0 0 1 0 6.74 4 4 0 0 1-4.77 4.78 4 4 0 0 1-6.75 0 4 4 0 0 1-4.78-4.77 4 4 0 0 1 0-6.76Z', variant: 'draw', animate: { pathLength: [0.25, 1], opacity: [0.45, 1] } },
        { key: 'stem', type: 'line', x1: 12, y1: 8, x2: 12, y2: 12, variant: 'lift', animate: { y: [-0.6, 0.6, 0] } },
        { key: 'dot', type: 'line', x1: 12, y1: 16, x2: 12.01, y2: 16, variant: 'fade', animate: { opacity: [0.2, 1], scale: [0.7, 1] } }
      ];
    case 'waypoints':
      return [
        { key: 'top', type: 'circle', cx: 12, cy: 4.5, r: 2.1, variant: 'pop', animate: { scale: [0.65, 1] } },
        { key: 'left', type: 'circle', cx: 4.5, cy: 12, r: 2.1, variant: 'pop', animate: { scale: [0.65, 1], transition: { delay: 0.04 } } },
        { key: 'right', type: 'circle', cx: 19.5, cy: 12, r: 2.1, variant: 'pop', animate: { scale: [0.65, 1], transition: { delay: 0.08 } } },
        { key: 'bottom', type: 'circle', cx: 12, cy: 19.5, r: 2.1, variant: 'pop', animate: { scale: [0.65, 1], transition: { delay: 0.12 } } },
        { key: 'diag-left', type: 'path', d: 'm10.2 6.3-3.9 3.9', variant: 'draw', animate: { pathLength: [0.1, 1], opacity: [0.3, 1], transition: { delay: 0.06 } } },
        { key: 'mid', type: 'path', d: 'M7 12h10', variant: 'draw', animate: { pathLength: [0.1, 1], opacity: [0.3, 1], transition: { delay: 0.1 } } },
        { key: 'diag-right', type: 'path', d: 'm13.8 17.7 3.9-3.9', variant: 'draw', animate: { pathLength: [0.1, 1], opacity: [0.3, 1], transition: { delay: 0.14 } } }
      ];
    case 'compass':
      return [
        { key: 'ring', type: 'circle', cx: 12, cy: 12, r: 9.5, variant: 'draw', animate: { pathLength: [0.2, 1], opacity: [0.4, 1] } },
        { key: 'needle', type: 'path', d: 'm14.8 9.2-2.1 5.6-5.5 2.1 2.1-5.6 5.5-2.1Z', variant: 'needle', animate: { rotate: [-6, 8, 0], scale: [0.92, 1] } }
      ];
    case 'sparkles':
      return [
        { key: 'core', type: 'path', d: 'M9.937 15.5A2 2 0 0 0 8.5 14.063l-6.135-1.582a.5.5 0 0 1 0-.962L8.5 9.936A2 2 0 0 0 9.937 8.5l1.582-6.135a.5.5 0 0 1 .963 0L14.063 8.5A2 2 0 0 0 15.5 9.937l6.135 1.581a.5.5 0 0 1 0 .964L15.5 14.063a2 2 0 0 0-1.437 1.437l-1.582 6.135a.5.5 0 0 1-.963 0z', variant: 'spark', animate: { y: [0, -0.8, 0], fill: ['none', active ? 'currentColor' : 'currentColor', 'none'] } },
        { key: 'star-v', type: 'path', d: 'M20 3v4', variant: 'blink', animate: { opacity: [0, 1, 0.2, 1] } },
        { key: 'star-h', type: 'path', d: 'M22 5h-4', variant: 'blink', animate: { opacity: [0, 1, 0.2, 1], transition: { delay: 0.05 } } },
        { key: 'mini-v', type: 'path', d: 'M4 17v2', variant: 'blink', animate: { opacity: [0, 1, 0.15, 1], transition: { delay: 0.08 } } },
        { key: 'mini-h', type: 'path', d: 'M5 18H3', variant: 'blink', animate: { opacity: [0, 1, 0.15, 1], transition: { delay: 0.12 } } }
      ];
    case 'graduation-cap':
      return [
        { key: 'cap', type: 'path', d: 'M2 10l10-5 10 5-10 5z', variant: 'tilt', animate: { rotate: [-2, 2, 0] } },
        { key: 'base', type: 'path', d: 'M6 12v5c3 3 9 3 12 0v-5', variant: 'draw', animate: { pathLength: [0.15, 1], opacity: [0.4, 1], transition: { delay: 0.08 } } }
      ];
    case 'message-circle':
      return [
        { key: 'bubble', type: 'path', d: 'M7.9 20A9 9 0 1 0 4 16.1L2 22Z', variant: 'draw', animate: { pathLength: [0.15, 1], opacity: [0.4, 1] } },
        { key: 'pulse', type: 'path', d: 'M8 12h8', variant: 'draw', animate: { pathLength: [0, 1], opacity: [0, 1], transition: { delay: 0.08 } } }
      ];
    case 'message-square':
      return [
        { key: 'bubble', type: 'path', d: 'M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z', variant: 'draw', animate: { pathLength: [0.15, 1], opacity: [0.4, 1] } },
        { key: 'pulse', type: 'path', d: 'M8 10h8', variant: 'draw', animate: { pathLength: [0, 1], opacity: [0, 1], transition: { delay: 0.08 } } }
      ];
    case 'mailbox':
      return [
        { key: 'body', type: 'path', d: 'M22 17a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V9.5C2 7 4 5 6.5 5H18c2.2 0 4 1.8 4 4v8Z', variant: 'draw', animate: { pathLength: [0.15, 1], opacity: [0.45, 1] } },
        { key: 'lid', type: 'path', d: 'M6.5 5C9 5 11 7 11 9.5V17a2 2 0 0 1-2 2', variant: 'lift', animate: { y: [-0.4, 0.5, 0] } },
        { key: 'dot', type: 'line', x1: 6, y1: 10, x2: 7, y2: 10, variant: 'fade', animate: { opacity: [0.3, 1], scale: [0.7, 1] } }
      ];
    case 'user':
      return [
        { key: 'head', type: 'circle', cx: 12, cy: 8, r: 4.6, variant: 'pop', animate: { scale: [0.7, 1] } },
        { key: 'body', type: 'path', d: 'M20 21a8 8 0 0 0-16 0', variant: 'draw', animate: { pathLength: [0.1, 1], opacity: [0.35, 1], transition: { delay: 0.08 } } }
      ];
    case 'circle-help':
      return [
        { key: 'ring', type: 'circle', cx: 12, cy: 12, r: 9.5, variant: 'draw', animate: { pathLength: [0.2, 1], opacity: [0.45, 1] } },
        { key: 'mark', type: 'path', d: 'M9.1 9a3 3 0 0 1 5.8 1c0 2-3 3-3 3', variant: 'draw', animate: { pathLength: [0.15, 1], opacity: [0.35, 1], transition: { delay: 0.05 } } },
        { key: 'dot', type: 'line', x1: 12, y1: 17, x2: 12.01, y2: 17, variant: 'fade', animate: { opacity: [0.2, 1], scale: [0.7, 1], transition: { delay: 0.1 } } }
      ];
    case 'clipboard-check':
      return [
        { key: 'clip', type: 'rect', x: 8, y: 2.4, width: 8, height: 4, rx: 1, variant: 'fade', animate: { opacity: [0.35, 1], y: [-0.5, 0] } },
        { key: 'page', type: 'path', d: 'M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2', variant: 'draw', animate: { pathLength: [0.15, 1], opacity: [0.4, 1] } },
        { key: 'check', type: 'path', d: 'm9.4 13.6 1.9 1.9 3.8-4.2', variant: 'draw', animate: { pathLength: [0.05, 1], opacity: [0, 1], transition: { delay: 0.12 } } }
      ];
    case 'search':
      return [
        { key: 'glass', type: 'circle', cx: 11, cy: 11, r: 7.2, variant: 'draw', animate: { pathLength: [0.2, 1], opacity: [0.45, 1] } },
        { key: 'handle', type: 'path', d: 'm21 21-4.3-4.3', variant: 'lift', animate: { x: [-0.6, 0.3, 0], y: [-0.6, 0.3, 0] } }
      ];
    case 'sliders-horizontal':
      return [
        { key: 'top-left', type: 'line', x1: 3, y1: 4, x2: 10, y2: 4, variant: 'line-slide', animate: { x2: [13, 10] } },
        { key: 'top-right', type: 'line', x1: 14, y1: 4, x2: 21, y2: 4, variant: 'line-slide', animate: { x1: [10, 14] } },
        { key: 'mid-left', type: 'line', x1: 3, y1: 12, x2: 8, y2: 12, variant: 'line-slide', animate: { x2: [13, 8] } },
        { key: 'mid-right', type: 'line', x1: 12, y1: 12, x2: 21, y2: 12, variant: 'line-slide', animate: { x1: [8, 12] } },
        { key: 'bottom-left', type: 'line', x1: 3, y1: 20, x2: 12, y2: 20, variant: 'line-slide', animate: { x2: [6, 12] } },
        { key: 'bottom-right', type: 'line', x1: 16, y1: 20, x2: 21, y2: 20, variant: 'line-slide', animate: { x1: [12, 16] } },
        { key: 'knob-a', type: 'line', x1: 14, y1: 2, x2: 14, y2: 6, variant: 'line-slide', animate: { x1: [9, 14], x2: [9, 14] } },
        { key: 'knob-b', type: 'line', x1: 8, y1: 10, x2: 8, y2: 14, variant: 'line-slide', animate: { x1: [14, 8], x2: [14, 8] } },
        { key: 'knob-c', type: 'line', x1: 16, y1: 18, x2: 16, y2: 22, variant: 'line-slide', animate: { x1: [8, 16], x2: [8, 16] } }
      ];
    case 'clock':
      return [
        { key: 'ring', type: 'circle', cx: 12, cy: 12, r: 9.5, variant: 'draw', animate: { pathLength: [0.2, 1], opacity: [0.45, 1] } },
        { key: 'hour', type: 'line', x1: 12, y1: 12, x2: 12, y2: 7, variant: 'clock', animate: { rotate: [0, 360], transformOrigin: '12px 12px' } },
        { key: 'minute', type: 'line', x1: 12, y1: 12, x2: 16, y2: 14, variant: 'clock', animate: { rotate: [0, 45], transformOrigin: '12px 12px', transition: { delay: 0.02 } } }
      ];
    case 'flame':
      return [
        { key: 'outer', type: 'path', d: 'M12 2s4 4.4 4 8.3c-.1 1.6-1 3.1-2.2 4.1-.4-1.9-1.5-3.6-3.3-4.8-1.7 1.5-2.6 3.4-2.6 5.4 0 3 2 5 4.1 6.1 3.7-1.3 6.1-4.8 6.1-8.7C18.1 6.2 12 2 12 2Z', variant: 'flame', animate: { scaleY: [0.92, 1.05, 0.98], y: [0.4, -0.6, 0] } },
        { key: 'inner', type: 'path', d: 'M12.2 11.4c1.3 1 2 2.2 2 3.6 0 1.8-1.2 3.3-2.8 4-1.6-.7-2.6-2.2-2.6-4 0-1.3.7-2.5 1.8-3.5.4.5.9 1 1.6 1.5Z', variant: 'fade', animate: { opacity: [0.35, 1], scale: [0.8, 1] } }
      ];
    case 'route':
      return [
        { key: 'line', type: 'path', d: 'M6 19c0-3.2 1.8-4.8 4.5-6.2 2.6-1.4 4.5-2.8 4.5-5.8', variant: 'draw', animate: { pathLength: [0.15, 1], opacity: [0.35, 1] } },
        { key: 'start', type: 'circle', cx: 6, cy: 19, r: 2, variant: 'pop', animate: { scale: [0.7, 1], transition: { delay: 0.05 } } },
        { key: 'end', type: 'circle', cx: 15, cy: 7, r: 2.2, variant: 'pop', animate: { scale: [0.7, 1], transition: { delay: 0.1 } } }
      ];
    case 'image':
      return [
        { key: 'frame', type: 'rect', x: 3, y: 4, width: 18, height: 16, rx: 2, variant: 'draw', animate: { pathLength: [0.2, 1], opacity: [0.45, 1] } },
        { key: 'sun', type: 'circle', cx: 9, cy: 9, r: 1.8, variant: 'pop', animate: { scale: [0.7, 1] } },
        { key: 'ridge', type: 'path', d: 'm5 17 4.2-4.2a1.2 1.2 0 0 1 1.7 0L14 16l2.1-2.1a1.2 1.2 0 0 1 1.7 0L19 15.1', variant: 'draw', animate: { pathLength: [0.1, 1], opacity: [0.35, 1], transition: { delay: 0.08 } } }
      ];
    case 'heart':
      return [
        { key: 'heart', type: 'path', d: 'M12 20.5s-7-4.4-7-10.3A4.2 4.2 0 0 1 9.2 6c1.4 0 2.3.6 2.8 1.3.5-.7 1.4-1.3 2.8-1.3A4.2 4.2 0 0 1 19 10.2c0 5.9-7 10.3-7 10.3z', variant: 'heart', fillable: true, animate: { scale: [0.88, 1.08, 1], fill: [active ? 'currentColor' : 'none', 'currentColor', active ? 'currentColor' : 'none'] } }
      ];
    default:
      return [
        { key: 'ring', type: 'circle', cx: 12, cy: 12, r: 8.5, variant: 'draw', animate: { pathLength: [0.2, 1], opacity: [0.45, 1] } }
      ];
  }
}

function MotionShape({ shape, hovered, strokeWidth, active }) {
  const motionProps = hovered
    ? shape.animate || {}
    : shape.variant === 'line-slide'
      ? undefined
      : shape.type === 'path' || shape.type === 'circle' || shape.type === 'rect'
        ? { opacity: 1, pathLength: 1, scale: 1, rotate: 0, y: 0, x: 0, fill: shape.fillable && active ? 'currentColor' : 'none' }
        : { opacity: 1, scale: 1, rotate: 0, y: 0, x: 0 };
  const transition = hovered
    ? { duration: 0.55, ease: [0.22, 1, 0.36, 1], ...(shape.animate?.transition || {}) }
    : { duration: 0.25, ease: [0.22, 1, 0.36, 1] };
  const common = {
    animate: motionProps,
    transition,
    fill: shape.fillable && active ? 'currentColor' : 'none',
    stroke: 'currentColor',
    strokeWidth,
    vectorEffect: 'non-scaling-stroke'
  };
  switch (shape.type) {
    case 'path':
      return <motion.path key={shape.key} d={shape.d} {...common} />;
    case 'circle':
      return <motion.circle key={shape.key} cx={shape.cx} cy={shape.cy} r={shape.r} {...common} />;
    case 'rect':
      return <motion.rect key={shape.key} x={shape.x} y={shape.y} width={shape.width} height={shape.height} rx={shape.rx} {...common} />;
    default:
      return <motion.line key={shape.key} x1={shape.x1} y1={shape.y1} x2={shape.x2} y2={shape.y2} {...common} />;
  }
}

export default function AnimatedIcon({
  name,
  size = 18,
  className = '',
  active = false,
  strokeWidth = 1.9,
  decorative = true
}) {
  const [hovered, setHovered] = useState(false);
  const shapes = useMemo(() => iconPrimitives(name, active), [name, active]);

  return (
    <span
      className={mergeClassName('animated-icon', className)}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      onFocus={() => setHovered(true)}
      onBlur={() => setHovered(false)}
      aria-hidden={decorative ? 'true' : undefined}
    >
      <motion.svg
        width={size}
        height={size}
        viewBox="0 0 24 24"
        fill="none"
        initial={false}
        animate={hovered ? { scale: 1.03 } : { scale: 1 }}
        transition={{ duration: 0.22, ease: [0.22, 1, 0.36, 1] }}
      >
        {shapes.map((shape) => (
          <MotionShape key={shape.key} shape={shape} hovered={hovered} strokeWidth={strokeWidth} active={active} />
        ))}
      </motion.svg>
    </span>
  );
}
