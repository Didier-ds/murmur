import {AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {RingLogo} from '../components/RingLogo';
import {clamp, easeOut, EMBER, fontFamily} from '../theme';

const NAME = 'Murmur';

/** Logo lock-up on a mirror floor. */
export const EndCard = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  const ringIn = spring({frame, fps, config: {damping: 14, stiffness: 120}});
  const level = interpolate(frame, [8, 20, 34, 44], [0, 1, 1, 0], clamp);
  const bar = (i: number) => 1 + level * 0.55 * Math.sin(frame * 0.6 + i * 1.3);
  const tagline = spring({frame: frame - 26, fps, config: {damping: 200}});
  const sweep = interpolate(frame, [32, 56], [-30, 130], clamp);

  return (
    <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center', fontFamily}}>
      <div style={{display: 'flex', alignItems: 'center', gap: 56, translate: '0 -60px', WebkitBoxReflect: 'below 10px linear-gradient(transparent 45%, rgba(255,255,255,0.22))'}}>
        <div style={{scale: interpolate(ringIn, [0, 1], [0.55, 1]), opacity: ringIn, rotate: `${interpolate(ringIn, [0, 1], [-120, 0])}deg`}}>
          <RingLogo size={190} bars={[bar(0), bar(1), bar(2)]} glow={interpolate(frame, [0, 20, 60], [30, 14, 8], clamp)} sheen={interpolate(frame, [30, 52], [-0.2, 1.2], clamp)} />
        </div>
        <div style={{display: 'flex', fontSize: 190, fontWeight: 800, letterSpacing: '-0.05em', lineHeight: 1}}>
          {NAME.split('').map((ch, i) => {
            const p = spring({frame: frame - 6 - i * 2.5, fps, config: {damping: 16, stiffness: 160}});
            return (
              <span
                key={i}
                style={{
                  display: 'inline-block',
                  backgroundImage: `linear-gradient(105deg, #8a8e9a ${sweep - 30}%, #ffffff ${sweep}%, #8a8e9a ${sweep + 30}%), linear-gradient(180deg, #ffffff 0%, #c9ccd6 55%, #7d818d 100%)`,
                  backgroundBlendMode: 'screen',
                  WebkitBackgroundClip: 'text',
                  backgroundClip: 'text',
                  color: 'transparent',
                  opacity: p,
                  translate: `0 ${interpolate(p, [0, 1], [90, 0])}px`,
                  filter: `blur(${interpolate(p, [0, 1], [12, 0])}px)`,
                }}
              >
                {ch}
              </span>
            );
          })}
        </div>
      </div>

      <div
        style={{
          position: 'absolute',
          top: 760,
          fontSize: 46,
          fontWeight: 500,
          letterSpacing: '-0.01em',
          color: 'rgba(255,255,255,0.7)',
          opacity: tagline,
          translate: `0 ${interpolate(tagline, [0, 1], [24, 0])}px`,
        }}
      >
        Speak anywhere on your Mac.
      </div>
      <div
        style={{
          position: 'absolute',
          top: 846,
          fontSize: 22,
          fontWeight: 600,
          letterSpacing: '0.28em',
          color: EMBER,
          opacity: interpolate(frame, [40, 54], [0, 1], {...clamp, easing: easeOut}),
        }}
      >
        ON-DEVICE · PRIVATE · INSTANT
      </div>
    </AbsoluteFill>
  );
};
