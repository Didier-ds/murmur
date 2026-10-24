import {useId} from 'react';
import {EMBER, ICE} from '../theme';

type Props = {
  readonly width: number;
  readonly height: number;
  /** 0..1 microphone level. */
  readonly level: number;
  /** Animation phase; advance it with the frame. */
  readonly phase: number;
};

const LAYERS = [
  {amp: 0.9, freq: 1, color: '#ffffff', opacity: 0.95, width: 3.2},
  {amp: 0.6, freq: 1.7, color: ICE, opacity: 0.55, width: 2.4},
  {amp: 0.4, freq: 2.6, color: EMBER, opacity: 0.7, width: 2},
] as const;

/** Liquid-mercury waveform, same math as the app's capsule. */
export const Waveform = ({width, height, level, phase}: Props) => {
  const id = useId().replace(/:/g, '');
  const mid = height / 2;

  return (
    <svg width={width} height={height} style={{overflow: 'visible'}}>
      <defs>
        {LAYERS.map((layer, i) => (
          <linearGradient key={i} id={`fade-${id}-${i}`} x1="0" y1="0" x2="1" y2="0">
            <stop offset="0" stopColor={layer.color} stopOpacity="0" />
            <stop offset="0.5" stopColor={layer.color} stopOpacity={layer.opacity} />
            <stop offset="1" stopColor={layer.color} stopOpacity="0" />
          </linearGradient>
        ))}
      </defs>
      {LAYERS.map((layer, i) => {
        let d = '';
        for (let step = 0; step <= 120; step++) {
          const n = step / 120;
          const envelope = Math.sin(Math.PI * n) ** 2;
          const y =
            mid +
            Math.sin(n * Math.PI * 4 * layer.freq + phase * layer.freq) * envelope * layer.amp * Math.max(level, 0.03) * height * 0.45 +
            Math.sin(n * 40 + phase * 3) * level * 2.5;
          d += `${step === 0 ? 'M' : 'L'}${(n * width).toFixed(1)},${y.toFixed(1)}`;
        }
        return (
          <path
            key={i}
            d={d}
            fill="none"
            stroke={`url(#fade-${id}-${i})`}
            strokeWidth={layer.width}
            strokeLinecap="round"
            style={{filter: `drop-shadow(0 0 6px ${layer.color})`}}
          />
        );
      })}
    </svg>
  );
};
