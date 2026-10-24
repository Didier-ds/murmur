import {AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {MirrorPanel} from '../components/Mirror';
import {clamp, easeInOut, easeOut, EMBER, fontFamily, ICE, silverText} from '../theme';

const BEAT = 30;

type Beat = {
  readonly kicker: string;
  readonly headline: string;
  readonly app: string;
  readonly context: string;
  readonly text: string;
  readonly badge?: string;
};

const BEATS: readonly Beat[] = [
  {kicker: 'WORKS EVERYWHERE', headline: 'Any app.', app: 'Messages', context: 'To: Maya', text: 'Running 5 min late, start without me!'},
  {kicker: 'PRIVATE BY DESIGN', headline: 'On-device.', app: 'Mail', context: 'Re: Q4 deck', text: 'Thanks for the notes. Deck coming tonight.'},
  {
    kicker: 'ZERO FRICTION',
    headline: 'Never loses a word.',
    app: 'Xcode',
    context: 'SpeechSession.swift',
    text: '// cache the voice model on first launch',
    badge: 'Copied · ⌘V',
  },
];

/** Three fast beats: a headline on the left, a tilted app card being typed into on the right. */
export const Anywhere = () => (
  <AbsoluteFill style={{fontFamily}}>
    {BEATS.map((beat, i) => (
      <BeatView key={beat.headline} beat={beat} start={i * BEAT} last={i === BEATS.length - 1} />
    ))}
  </AbsoluteFill>
);

const BeatView = ({beat, start, last}: {readonly beat: Beat; readonly start: number; readonly last: boolean}) => {
  const frame = useCurrentFrame() - start;
  const {fps} = useVideoConfig();
  if (frame < -2 || frame > (last ? 40 : BEAT + 4)) return null;

  const enter = spring({frame, fps, config: {damping: 18, stiffness: 180}});
  const exit = interpolate(frame, last ? [31, 40] : [BEAT - 4, BEAT + 4], [0, 1], {...clamp, easing: easeInOut});
  const typed = Math.floor(interpolate(frame, [7, 22], [0, beat.text.length], clamp));
  const badge = spring({frame: frame - 23, fps, config: {damping: 12}});

  return (
    <AbsoluteFill>
      <div
        style={{
          position: 'absolute',
          left: 130,
          top: 360,
          width: 820,
          opacity: (1 - exit) * enter,
          translate: `${interpolate(exit, [0, 1], [0, -120])}px ${interpolate(enter, [0, 1], [80, 0])}px`,
          filter: `blur(${(1 - enter) * 16 + exit * 16}px)`,
        }}
      >
        <div style={{fontSize: 26, fontWeight: 700, letterSpacing: '0.22em', color: EMBER, marginBottom: 18}}>{beat.kicker}</div>
        <div style={{fontSize: 132, fontWeight: 800, letterSpacing: '-0.045em', lineHeight: 0.98, ...silverText}}>{beat.headline}</div>
      </div>

      <div
        style={{
          position: 'absolute',
          left: 1000,
          top: 300,
          width: 780,
          height: 470,
          perspective: 1600,
          opacity: 1 - exit,
        }}
      >
        <MirrorPanel
          radius={30}
          sheen={interpolate(frame, [4, 26], [-0.3, 1.3], clamp)}
          style={{
            inset: 0,
            rotate: `y ${interpolate(enter, [0, 1], [-38, -14])}deg`,
            translate: `${interpolate(enter, [0, 1], [420, 0]) + interpolate(exit, [0, 1], [0, -260])}px ${interpolate(exit, [0, 1], [0, 30])}px`,
            filter: `blur(${exit * 14}px)`,
          }}
        >
          <div style={{height: 70, display: 'flex', alignItems: 'center', gap: 12, padding: '0 28px', borderBottom: '1px solid rgba(255,255,255,0.07)'}}>
            {[0, 1, 2].map((d) => (
              <div key={d} style={{width: 15, height: 15, borderRadius: 8, background: '#3a3a44'}} />
            ))}
            <span style={{marginLeft: 16, fontSize: 24, fontWeight: 700, color: 'rgba(255,255,255,0.8)'}}>{beat.app}</span>
            <span style={{marginLeft: 'auto', fontSize: 20, color: 'rgba(255,255,255,0.4)'}}>{beat.context}</span>
          </div>
          <div style={{padding: '40px 40px', fontSize: 40, lineHeight: 1.45, fontWeight: 500, color: '#f1f1f5'}}>
            {beat.text.slice(0, typed)}
            <span
              style={{
                display: 'inline-block',
                width: 4,
                height: 46,
                marginLeft: 4,
                translate: '0 9px',
                background: typed < beat.text.length ? ICE : EMBER,
                boxShadow: `0 0 12px ${typed < beat.text.length ? ICE : EMBER}`,
                opacity: typed < beat.text.length || Math.floor(frame / 6) % 2 === 0 ? 1 : 0,
              }}
            />
          </div>
          {beat.badge ? (
            <div
              style={{
                position: 'absolute',
                right: 34,
                bottom: 34,
                padding: '12px 22px',
                borderRadius: 16,
                fontSize: 24,
                fontWeight: 600,
                color: '#0a0a0f',
                background: 'linear-gradient(180deg, #fff, #c3c6d0)',
                boxShadow: '0 10px 30px rgba(207,230,255,0.25)',
                opacity: badge,
                scale: interpolate(badge, [0, 1], [0.6, 1]),
              }}
            >
              {beat.badge}
            </div>
          ) : null}
        </MirrorPanel>
      </div>

      {/* Ember underline sweep that ties headline and card together. */}
      <div
        style={{
          position: 'absolute',
          left: 130,
          top: last ? 700 : 568,
          height: 4,
          borderRadius: 2,
          width: interpolate(frame, [6, 20], [0, 340], {...clamp, easing: easeOut}),
          background: `linear-gradient(90deg, ${EMBER}, transparent)`,
          boxShadow: `0 0 16px ${EMBER}`,
          opacity: 1 - exit,
        }}
      />
    </AbsoluteFill>
  );
};
