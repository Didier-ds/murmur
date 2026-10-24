import {useId} from 'react';
import {EMBER} from '../theme';

type Props = {
  readonly size: number;
  /** 0..1, how much of the ring stroke is drawn. */
  readonly draw?: number;
  /** Vertical scale of the three bars. */
  readonly bars?: readonly [number, number, number];
  readonly mode?: 'chrome' | 'white' | 'ember';
  /** Rotation in degrees; when set, only a short arc is drawn (the "busy" state). */
  readonly busyAngle?: number | null;
  readonly glow?: number;
  /** -1..2, position of a specular sweep across the ring. */
  readonly sheen?: number;
};

const R = 40;
const CIRC = 2 * Math.PI * R;

/** The Murmur mark: a ring with three bars. */
export const RingLogo = ({size, draw = 1, bars = [1, 1, 1], mode = 'chrome', busyAngle = null, glow = 0, sheen = -1}: Props) => {
  const id = useId().replace(/:/g, '');
  const stroke = mode === 'chrome' ? `url(#chrome-${id})` : mode === 'ember' ? EMBER : '#ffffff';
  const fill = mode === 'chrome' ? `url(#chrome-${id})` : mode === 'ember' ? EMBER : '#ffffff';
  const glowColor = mode === 'ember' ? EMBER : 'rgba(207,230,255,0.9)';
  const head = (draw * 360 - 90) * (Math.PI / 180);

  return (
    <svg
      viewBox="0 0 100 100"
      width={size}
      height={size}
      style={{overflow: 'visible', filter: glow > 0 ? `drop-shadow(0 0 ${glow}px ${glowColor})` : undefined}}
    >
      <defs>
        <linearGradient id={`chrome-${id}`} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor="#ffffff" />
          <stop offset="35%" stopColor="#a4a9b6" />
          <stop offset="55%" stopColor="#f4f6fb" />
          <stop offset="100%" stopColor="#5b5f6b" />
        </linearGradient>
        <linearGradient id={`sheen-${id}`} x1="0" y1="0" x2="1" y2="0.4">
          <stop offset={Math.max(0, sheen - 0.15)} stopColor="#fff" stopOpacity="0" />
          <stop offset={Math.min(1, Math.max(0, sheen))} stopColor="#fff" stopOpacity="0.95" />
          <stop offset={Math.min(1, sheen + 0.15)} stopColor="#fff" stopOpacity="0" />
        </linearGradient>
      </defs>

      {busyAngle === null ? (
        <circle
          cx="50"
          cy="50"
          r={R}
          fill="none"
          stroke={stroke}
          strokeWidth="6.5"
          strokeLinecap="round"
          strokeDasharray={CIRC}
          strokeDashoffset={CIRC * (1 - draw)}
          transform="rotate(-90 50 50)"
        />
      ) : (
        <circle
          cx="50"
          cy="50"
          r={R}
          fill="none"
          stroke={stroke}
          strokeWidth="6.5"
          strokeLinecap="round"
          strokeDasharray={`${CIRC * 0.3} ${CIRC}`}
          transform={`rotate(${busyAngle - 90} 50 50)`}
        />
      )}

      {/* Ember spark riding the head of the stroke while it draws. */}
      {draw > 0.01 && draw < 0.995 ? (
        <circle cx={50 + R * Math.cos(head)} cy={50 + R * Math.sin(head)} r="4.5" fill={EMBER} style={{filter: `drop-shadow(0 0 6px ${EMBER})`}} />
      ) : null}

      {[24, 44, 24].map((h, i) => {
        const height = Math.max(0.001, h * bars[i]);
        return (
          <rect key={i} x={32 + i * 14.5 - 4.5} y={50 - height / 2} width="9" height={height} rx="4.5" fill={fill} />
        );
      })}

      {sheen > -0.2 && sheen < 1.2 ? (
        <g style={{mixBlendMode: 'screen'}}>
          <circle cx="50" cy="50" r={R} fill="none" stroke={`url(#sheen-${id})`} strokeWidth="6.5" />
          {[24, 44, 24].map((h, i) => {
            const height = Math.max(0.001, h * bars[i]);
            return <rect key={i} x={32 + i * 14.5 - 4.5} y={50 - height / 2} width="9" height={height} rx="4.5" fill={`url(#sheen-${id})`} />;
          })}
        </g>
      ) : null}
    </svg>
  );
};
