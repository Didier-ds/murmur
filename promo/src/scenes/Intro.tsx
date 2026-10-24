import {AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {RingLogo} from '../components/RingLogo';
import {clamp, easeOut, EMBER, fontFamily, ICE, silverText} from '../theme';

const TYPED = 'It types.';

/** Black void → the ring draws itself → "Speak. It types." */
export const Intro = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  const draw = interpolate(frame, [4, 38], [0, 1], {...clamp, easing: easeOut});
  const bar = (delay: number) => spring({frame: frame - 30 - delay, fps, config: {damping: 11, stiffness: 160}});
  const bars: [number, number, number] = [bar(0), bar(3), bar(6)];
  const sheen = interpolate(frame, [44, 66], [-0.2, 1.2], clamp);
  const glow = interpolate(frame, [36, 46, 70], [0, 26, 10], clamp);

  const speakIn = spring({frame: frame - 40, fps, config: {damping: 200}});
  const typedChars = Math.floor(interpolate(frame, [54, 72], [0, TYPED.length], clamp));
  const caretOn = frame < 54 || Math.floor(frame / 8) % 2 === 0;

  return (
    <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center', fontFamily}}>
      <div
        style={{
          scale: interpolate(frame, [0, 70], [1.25, 1], {...clamp, easing: easeOut}),
          translate: `0 ${interpolate(frame, [34, 60], [70, -10], {...clamp, easing: easeOut})}px`,
        }}
      >
        <RingLogo size={260} draw={draw} bars={bars} glow={glow} sheen={sheen} />
      </div>

      <div
        style={{
          position: 'absolute',
          top: 690,
          display: 'flex',
          gap: 36,
          fontSize: 120,
          fontWeight: 700,
          letterSpacing: '-0.035em',
          lineHeight: 1,
        }}
      >
        <span
          style={{
            ...silverText,
            opacity: speakIn,
            translate: `0 ${interpolate(speakIn, [0, 1], [50, 0])}px`,
            filter: `blur(${interpolate(speakIn, [0, 1], [14, 0])}px)`,
          }}
        >
          Speak.
        </span>
        <span style={{position: 'relative'}}>
          <span style={{visibility: 'hidden'}}>{TYPED}</span>
          <span style={{position: 'absolute', left: 0, top: 0, whiteSpace: 'nowrap'}}>
          <span style={silverText}>{TYPED.slice(0, typedChars)}</span>
          {frame >= 50 ? (
            <span
              style={{
                display: 'inline-block',
                width: 7,
                height: 104,
                marginLeft: 8,
                translate: '0 10px',
                borderRadius: 4,
                background: typedChars === TYPED.length ? EMBER : ICE,
                boxShadow: `0 0 18px ${typedChars === TYPED.length ? EMBER : ICE}`,
                opacity: caretOn ? 1 : 0,
              }}
            />
          ) : null}
          </span>
        </span>
      </div>
    </AbsoluteFill>
  );
};
