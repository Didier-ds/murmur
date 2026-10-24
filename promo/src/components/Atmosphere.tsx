import {AbsoluteFill, useCurrentFrame} from 'remotion';

/** Deep black stage with slowly drifting light, shared by every scene so cuts feel continuous. */
export const Backdrop = () => {
  const frame = useCurrentFrame();
  const t = frame / 30;
  return (
    <AbsoluteFill
      style={{
        backgroundColor: '#050507',
        backgroundImage: [
          `radial-gradient(45% 40% at ${72 + Math.sin(t * 0.5) * 8}% ${20 + Math.cos(t * 0.4) * 6}%, rgba(110,140,255,0.16), transparent 70%)`,
          `radial-gradient(40% 35% at ${22 + Math.cos(t * 0.35) * 7}% ${88 + Math.sin(t * 0.45) * 5}%, rgba(255,90,60,0.11), transparent 70%)`,
          'linear-gradient(180deg, #07070b 0%, #0b0b11 60%, #040405 100%)',
        ].join(','),
      }}
    />
  );
};

/** Film grain + vignette on top of everything. */
export const Grain = () => {
  const frame = useCurrentFrame();
  return (
    <>
      <AbsoluteFill style={{pointerEvents: 'none', mixBlendMode: 'overlay', opacity: 0.16}}>
        <svg width="100%" height="100%">
          <filter id="grain">
            <feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves="2" seed={frame % 12} stitchTiles="stitch" />
            <feColorMatrix type="saturate" values="0" />
          </filter>
          <rect width="100%" height="100%" filter="url(#grain)" />
        </svg>
      </AbsoluteFill>
      <AbsoluteFill
        style={{
          pointerEvents: 'none',
          background: 'radial-gradient(ellipse at center, transparent 55%, rgba(0,0,0,0.7) 100%)',
        }}
      />
    </>
  );
};
