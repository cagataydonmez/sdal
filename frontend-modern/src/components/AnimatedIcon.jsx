import React, { useMemo, useState } from 'react';

function mergeClassName(...parts) {
  return parts.filter(Boolean).join(' ');
}

function iconPrimitives(name) {
  switch (name) {
    case 'chevron-down':
      return [
        { key: 'left', type: 'line', x1: 6, y1: 9, x2: 12, y2: 15, drawFrom: 0.25 },
        { key: 'right', type: 'line', x1: 12, y1: 15, x2: 18, y2: 9, drawFrom: 0.25, delay: 40 }
      ];
    case 'menu':
      return [
        { key: 'top', type: 'line', x1: 4, y1: 7, x2: 20, y2: 7, hovered: { x1: 6, x2: 18 } },
        { key: 'mid', type: 'line', x1: 4, y1: 12, x2: 20, y2: 12, hovered: { x1: 3, x2: 21 } },
        { key: 'bottom', type: 'line', x1: 4, y1: 17, x2: 20, y2: 17, hovered: { x1: 6, x2: 18 } }
      ];
    case 'home':
      return [
        { key: 'roof', type: 'path', d: 'M3 10.4 12 3l9 7.4', drawFrom: 0.2 },
        { key: 'body', type: 'path', d: 'M6 10v10h12V10', drawFrom: 0.35, delay: 30 },
        { key: 'door', type: 'path', d: 'M10 20v-5a2 2 0 0 1 4 0v5', drawFrom: 0.4, delay: 60, hovered: { scaleY: 1.08, origin: '12px 20px' } }
      ];
    case 'users':
      return [
        { key: 'left-head', type: 'circle', cx: 8, cy: 9, r: 2.75, hovered: { scale: 1.08, origin: '8px 9px' } },
        { key: 'right-head', type: 'circle', cx: 16, cy: 9, r: 2.75, hovered: { scale: 1.08, origin: '16px 9px' }, delay: 30 },
        { key: 'left-body', type: 'path', d: 'M3.8 19c.9-2.6 2.8-3.9 4.2-3.9', drawFrom: 0.2 },
        { key: 'right-body', type: 'path', d: 'M20.2 19c-.9-2.6-2.8-3.9-4.2-3.9', drawFrom: 0.2, delay: 30 },
        { key: 'center-body', type: 'path', d: 'M8.8 18.2c.9-2.2 2-3.2 3.2-3.2s2.3 1 3.2 3.2', drawFrom: 0.2, delay: 60 }
      ];
    case 'calendar':
      return [
        { key: 'frame', type: 'rect', x: 3, y: 4.5, width: 18, height: 16.5, rx: 2.4, drawFrom: 0.2 },
        { key: 'line', type: 'path', d: 'M3 10.5h18', drawFrom: 0.2, delay: 30 },
        { key: 'left-pin', type: 'path', d: 'M8 2.8v4.4', hovered: { y: 0.4 }, delay: 20 },
        { key: 'right-pin', type: 'path', d: 'M16 2.8v4.4', hovered: { y: -0.4 }, delay: 40 }
      ];
    case 'bell':
      return [
        { key: 'shell', type: 'path', d: 'M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9', hovered: { rotate: 8, origin: '12px 11px' } },
        { key: 'clapper', type: 'path', d: 'M10.4 20.8a1.85 1.85 0 0 0 3.2 0', hovered: { scale: 1.08, origin: '12px 20px' }, delay: 30 }
      ];
    case 'badge-alert':
      return [
        { key: 'burst', type: 'path', d: 'M3.85 8.62a4 4 0 0 1 4.78-4.77 4 4 0 0 1 6.74 0 4 4 0 0 1 4.78 4.78 4 4 0 0 1 0 6.74 4 4 0 0 1-4.77 4.78 4 4 0 0 1-6.75 0 4 4 0 0 1-4.78-4.77 4 4 0 0 1 0-6.76Z', drawFrom: 0.25 },
        { key: 'stem', type: 'line', x1: 12, y1: 8, x2: 12, y2: 12, hovered: { y: 0.6 }, delay: 20 },
        { key: 'dot', type: 'line', x1: 12, y1: 16, x2: 12.01, y2: 16, hovered: { scale: 1.18, origin: '12px 16px' }, delay: 40 }
      ];
    case 'waypoints':
      return [
        { key: 'top', type: 'circle', cx: 12, cy: 4.5, r: 2.1, hovered: { scale: 1.06, origin: '12px 4.5px' } },
        { key: 'left', type: 'circle', cx: 4.5, cy: 12, r: 2.1, hovered: { scale: 1.06, origin: '4.5px 12px' }, delay: 25 },
        { key: 'right', type: 'circle', cx: 19.5, cy: 12, r: 2.1, hovered: { scale: 1.06, origin: '19.5px 12px' }, delay: 50 },
        { key: 'bottom', type: 'circle', cx: 12, cy: 19.5, r: 2.1, hovered: { scale: 1.06, origin: '12px 19.5px' }, delay: 75 },
        { key: 'diag-left', type: 'path', d: 'm10.2 6.3-3.9 3.9', drawFrom: 0.1, delay: 20 },
        { key: 'mid', type: 'path', d: 'M7 12h10', drawFrom: 0.1, delay: 45 },
        { key: 'diag-right', type: 'path', d: 'm13.8 17.7 3.9-3.9', drawFrom: 0.1, delay: 70 }
      ];
    case 'compass':
      return [
        { key: 'ring', type: 'circle', cx: 12, cy: 12, r: 9.5, drawFrom: 0.2 },
        { key: 'needle', type: 'path', d: 'm14.8 9.2-2.1 5.6-5.5 2.1 2.1-5.6 5.5-2.1Z', hovered: { rotate: 8, origin: '12px 12px', scale: 1.04 } }
      ];
    case 'sparkles':
      return [
        { key: 'core', type: 'path', d: 'M9.937 15.5A2 2 0 0 0 8.5 14.063l-6.135-1.582a.5.5 0 0 1 0-.962L8.5 9.936A2 2 0 0 0 9.937 8.5l1.582-6.135a.5.5 0 0 1 .963 0L14.063 8.5A2 2 0 0 0 15.5 9.937l6.135 1.581a.5.5 0 0 1 0 .964L15.5 14.063a2 2 0 0 0-1.437 1.437l-1.582 6.135a.5.5 0 0 1-.963 0z', hovered: { y: -0.8 } },
        { key: 'star-v', type: 'path', d: 'M20 3v4', drawFrom: 0.1, delay: 30 },
        { key: 'star-h', type: 'path', d: 'M22 5h-4', drawFrom: 0.1, delay: 45 },
        { key: 'mini-v', type: 'path', d: 'M4 17v2', drawFrom: 0.1, delay: 60 },
        { key: 'mini-h', type: 'path', d: 'M5 18H3', drawFrom: 0.1, delay: 75 }
      ];
    case 'graduation-cap':
      return [
        { key: 'cap', type: 'path', d: 'M2 10l10-5 10 5-10 5z', hovered: { rotate: 2, origin: '12px 10px' } },
        { key: 'base', type: 'path', d: 'M6 12v5c3 3 9 3 12 0v-5', drawFrom: 0.2, delay: 40 }
      ];
    case 'message-circle':
      return [
        { key: 'bubble', type: 'path', d: 'M7.9 20A9 9 0 1 0 4 16.1L2 22Z', drawFrom: 0.15 },
        { key: 'pulse', type: 'path', d: 'M8 12h8', drawFrom: 0.15, delay: 50 }
      ];
    case 'message-square':
      return [
        { key: 'bubble', type: 'path', d: 'M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z', drawFrom: 0.15 },
        { key: 'pulse', type: 'path', d: 'M8 10h8', drawFrom: 0.15, delay: 50 }
      ];
    case 'mailbox':
      return [
        { key: 'body', type: 'path', d: 'M22 17a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V9.5C2 7 4 5 6.5 5H18c2.2 0 4 1.8 4 4v8Z', drawFrom: 0.15 },
        { key: 'lid', type: 'path', d: 'M6.5 5C9 5 11 7 11 9.5V17a2 2 0 0 1-2 2', hovered: { y: 0.5 }, delay: 30 },
        { key: 'dot', type: 'line', x1: 6, y1: 10, x2: 7, y2: 10, hovered: { scale: 1.2, origin: '6.5px 10px' }, delay: 50 }
      ];
    case 'user':
      return [
        { key: 'head', type: 'circle', cx: 12, cy: 8, r: 4.6, hovered: { scale: 1.08, origin: '12px 8px' } },
        { key: 'body', type: 'path', d: 'M20 21a8 8 0 0 0-16 0', drawFrom: 0.1, delay: 40 }
      ];
    case 'circle-help':
      return [
        { key: 'ring', type: 'circle', cx: 12, cy: 12, r: 9.5, drawFrom: 0.2 },
        { key: 'mark', type: 'path', d: 'M9.1 9a3 3 0 0 1 5.8 1c0 2-3 3-3 3', drawFrom: 0.15, delay: 30 },
        { key: 'dot', type: 'line', x1: 12, y1: 17, x2: 12.01, y2: 17, hovered: { scale: 1.18, origin: '12px 17px' }, delay: 50 }
      ];
    case 'clipboard-check':
      return [
        { key: 'clip', type: 'rect', x: 8, y: 2.4, width: 8, height: 4, rx: 1, hovered: { y: -0.4 } },
        { key: 'page', type: 'path', d: 'M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2', drawFrom: 0.15, delay: 20 },
        { key: 'check', type: 'path', d: 'm9.4 13.6 1.9 1.9 3.8-4.2', drawFrom: 0.05, delay: 60 }
      ];
    case 'search':
      return [
        { key: 'glass', type: 'circle', cx: 11, cy: 11, r: 7.2, drawFrom: 0.2 },
        { key: 'handle', type: 'path', d: 'm21 21-4.3-4.3', hovered: { x: 0.3, y: 0.3 } }
      ];
    case 'sliders-horizontal':
      return [
        { key: 'top-left', type: 'line', x1: 3, y1: 4, x2: 10, y2: 4, hovered: { x2: 13 } },
        { key: 'top-right', type: 'line', x1: 14, y1: 4, x2: 21, y2: 4, hovered: { x1: 10 } },
        { key: 'mid-left', type: 'line', x1: 3, y1: 12, x2: 8, y2: 12, hovered: { x2: 13 } },
        { key: 'mid-right', type: 'line', x1: 12, y1: 12, x2: 21, y2: 12, hovered: { x1: 8 } },
        { key: 'bottom-left', type: 'line', x1: 3, y1: 20, x2: 12, y2: 20, hovered: { x2: 6 } },
        { key: 'bottom-right', type: 'line', x1: 16, y1: 20, x2: 21, y2: 20, hovered: { x1: 12 } },
        { key: 'knob-a', type: 'line', x1: 14, y1: 2, x2: 14, y2: 6, hovered: { x1: 9, x2: 9 } },
        { key: 'knob-b', type: 'line', x1: 8, y1: 10, x2: 8, y2: 14, hovered: { x1: 14, x2: 14 } },
        { key: 'knob-c', type: 'line', x1: 16, y1: 18, x2: 16, y2: 22, hovered: { x1: 8, x2: 8 } }
      ];
    case 'clock':
      return [
        { key: 'ring', type: 'circle', cx: 12, cy: 12, r: 9.5, drawFrom: 0.2 },
        { key: 'hour', type: 'line', x1: 12, y1: 12, x2: 12, y2: 7, hovered: { rotate: 360, origin: '12px 12px' } },
        { key: 'minute', type: 'line', x1: 12, y1: 12, x2: 16, y2: 14, hovered: { rotate: 45, origin: '12px 12px' }, delay: 20 }
      ];
    case 'flame':
      return [
        { key: 'outer', type: 'path', d: 'M12 2s4 4.4 4 8.3c-.1 1.6-1 3.1-2.2 4.1-.4-1.9-1.5-3.6-3.3-4.8-1.7 1.5-2.6 3.4-2.6 5.4 0 3 2 5 4.1 6.1 3.7-1.3 6.1-4.8 6.1-8.7C18.1 6.2 12 2 12 2Z', hovered: { scaleY: 1.06, y: -0.4, origin: '12px 12px' } },
        { key: 'inner', type: 'path', d: 'M12.2 11.4c1.3 1 2 2.2 2 3.6 0 1.8-1.2 3.3-2.8 4-1.6-.7-2.6-2.2-2.6-4 0-1.3.7-2.5 1.8-3.5.4.5.9 1 1.6 1.5Z', hovered: { scale: 1.08, origin: '12px 15px' }, delay: 30 }
      ];
    case 'route':
      return [
        { key: 'line', type: 'path', d: 'M6 19c0-3.2 1.8-4.8 4.5-6.2 2.6-1.4 4.5-2.8 4.5-5.8', drawFrom: 0.15 },
        { key: 'start', type: 'circle', cx: 6, cy: 19, r: 2, hovered: { scale: 1.12, origin: '6px 19px' }, delay: 30 },
        { key: 'end', type: 'circle', cx: 15, cy: 7, r: 2.2, hovered: { scale: 1.12, origin: '15px 7px' }, delay: 60 }
      ];
    case 'image':
      return [
        { key: 'frame', type: 'rect', x: 3, y: 4, width: 18, height: 16, rx: 2, drawFrom: 0.2 },
        { key: 'sun', type: 'circle', cx: 9, cy: 9, r: 1.8, hovered: { scale: 1.15, origin: '9px 9px' } },
        { key: 'ridge', type: 'path', d: 'm5 17 4.2-4.2a1.2 1.2 0 0 1 1.7 0L14 16l2.1-2.1a1.2 1.2 0 0 1 1.7 0L19 15.1', drawFrom: 0.1, delay: 40 }
      ];
    case 'heart':
      return [
        { key: 'heart', type: 'path', d: 'M12 20.5s-7-4.4-7-10.3A4.2 4.2 0 0 1 9.2 6c1.4 0 2.3.6 2.8 1.3.5-.7 1.4-1.3 2.8-1.3A4.2 4.2 0 0 1 19 10.2c0 5.9-7 10.3-7 10.3z', fillable: true, hovered: { scale: 1.08, origin: '12px 13px' } }
      ];
    default:
      return [{ key: 'ring', type: 'circle', cx: 12, cy: 12, r: 8.5, drawFrom: 0.2 }];
  }
}

function getTransform(shape, hovered) {
  if (!hovered || !shape.hovered) return undefined;
  const scale = shape.hovered.scale ?? 1;
  const scaleY = shape.hovered.scaleY ?? 1;
  const rotate = shape.hovered.rotate ?? 0;
  const x = shape.hovered.x ?? 0;
  const y = shape.hovered.y ?? 0;
  const parts = [];
  if (x || y) parts.push(`translate(${x}px, ${y}px)`);
  if (scale !== 1) parts.push(`scale(${scale})`);
  if (scaleY !== 1) parts.push(`scaleY(${scaleY})`);
  if (rotate) parts.push(`rotate(${rotate}deg)`);
  return parts.length ? parts.join(' ') : undefined;
}

function getDrawStyle(shape, hovered) {
  if (typeof shape.drawFrom !== 'number') return null;
  return {
    pathLength: 1,
    strokeDasharray: 1,
    strokeDashoffset: hovered ? 0 : 1 - shape.drawFrom,
    opacity: hovered ? 1 : 0.45
  };
}

function Shape({ shape, hovered, strokeWidth, active }) {
  const drawStyle = getDrawStyle(shape, hovered);
  const style = {
    transition: `transform 260ms cubic-bezier(0.22, 1, 0.36, 1) ${shape.delay || 0}ms, stroke-dashoffset 320ms cubic-bezier(0.22, 1, 0.36, 1) ${shape.delay || 0}ms, opacity 220ms ease ${shape.delay || 0}ms, fill 220ms ease ${shape.delay || 0}ms`,
    transform: getTransform(shape, hovered),
    transformOrigin: shape.hovered?.origin || 'center',
    opacity: drawStyle?.opacity ?? 1,
    strokeDasharray: drawStyle?.strokeDasharray,
    strokeDashoffset: drawStyle?.strokeDashoffset
  };
  const common = {
    key: shape.key,
    stroke: 'currentColor',
    strokeWidth,
    fill: shape.fillable && active ? 'currentColor' : 'none',
    vectorEffect: 'non-scaling-stroke',
    style
  };
  switch (shape.type) {
    case 'path':
      return <path d={shape.d} {...common} />;
    case 'circle':
      return <circle cx={shape.cx} cy={shape.cy} r={shape.r} {...common} />;
    case 'rect':
      return <rect x={shape.x} y={shape.y} width={shape.width} height={shape.height} rx={shape.rx} {...common} />;
    default:
      return <line x1={shape.x1} y1={shape.y1} x2={hovered && shape.hovered?.x2 != null ? shape.hovered.x2 : shape.x2} y2={shape.y2} x1={hovered && shape.hovered?.x1 != null ? shape.hovered.x1 : shape.x1} {...common} />;
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
  const shapes = useMemo(() => iconPrimitives(name), [name]);

  return (
    <span
      className={mergeClassName('animated-icon', className)}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      onFocus={() => setHovered(true)}
      onBlur={() => setHovered(false)}
      aria-hidden={decorative ? 'true' : undefined}
    >
      <svg
        width={size}
        height={size}
        viewBox="0 0 24 24"
        fill="none"
        style={{
          overflow: 'visible',
          transition: 'transform 220ms cubic-bezier(0.22, 1, 0.36, 1)',
          transform: hovered ? 'scale(1.03)' : 'scale(1)'
        }}
      >
        {shapes.map((shape) => (
          <Shape key={shape.key} shape={shape} hovered={hovered} strokeWidth={strokeWidth} active={active} />
        ))}
      </svg>
    </span>
  );
}
