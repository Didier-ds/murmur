import {AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {MirrorPanel} from '../components/Mirror';
import {RingLogo} from '../components/RingLogo';
import {Waveform} from '../components/Waveform';
import {clamp, easeInOut, easeOut, EMBER, fontFamily, ICE, silverText} from '../theme';

// Story beats (scene-local frames).
const CLICK = 55;
const WORDS_START = 76;
const ESC_PRESS = 162;
const FLY_START = 176;
const LAND = 206;

const SENTENCE = 'Ship the onboarding flow by Friday, and loop in design for the final review.';
const WORDS = SENTENCE.split(' ');

// Layout in desktop coordinates (1920×1080 before the camera).
const RING = {x: 1560, y: 26};
const CAPSULE = {left: 1180, top: 74, width: 700};
const NOTE = {left: 150, top: 170, width: 940, height: 640};
const CARET = {x: 352, y: 470};

/** Mic level while listening: lively but smooth. */
const levelAt = (f: number) => {
  const on = interpolate(f, [CLICK + 4, CLICK + 16, ESC_PRESS, ESC_PRESS + 14], [0, 1, 1, 0], clamp);
  const voice = 0.3 + 0.55 * Math.abs(Math.sin(f * 0.31) * Math.sin(f * 0.11 + 1)) + 0.1 * Math.sin(f * 1.7);
  return on * Math.min(1, Math.max(0, voice));
};

/** Camera keyframes: where we look (focus point) and how close. */
const camera = (f: number) => {
  const frames = [0, 62, 98, 168, 202, 240];
  const opts = {...clamp, easing: easeInOut};
  return {
    scale: interpolate(f, frames, [1, 1, 1.38, 1.38, 1.18, 1.1], opts),
    fx: interpolate(f, frames, [960, 960, 1530, 1530, 640, 620], opts),
    fy: interpolate(f, frames, [540, 540, 300, 300, 520, 520], opts),
  };
};

export const Desktop = () => {
  const frame = useCurrentFrame();
  const cam = camera(frame);

  return (
    <AbsoluteFill style={{fontFamily, color: '#e9e9ef'}}>
      <AbsoluteFill
        style={{
          scale: cam.scale,
          translate: `${-(cam.fx - 960) * cam.scale}px ${-(cam.fy - 540) * cam.scale}px`,
        }}
      >
        <MenuBar />
        <NoteWindow />
        <Capsule />
        <FlyingText />
        <Cursor />
      </AbsoluteFill>
      <LowerThird />
      <EscKey />
    </AbsoluteFill>
  );
};

const MenuBar = () => {
  const frame = useCurrentFrame();
  const recording = frame >= CLICK && frame < ESC_PRESS;
  const busy = frame >= ESC_PRESS && frame < LAND;
  const level = levelAt(frame);
  const wobble = (i: number) => 0.75 + 0.25 * Math.sin(frame * (0.5 + i * 0.27));
  const bars: [number, number, number] = recording
    ? [0.35 + level * wobble(0), 0.35 + level * 1.1 * wobble(1), 0.35 + level * wobble(2)]
    : [1, 1, 1];
  const ripple = interpolate(frame, [CLICK, CLICK + 22], [0, 1], clamp);

  return (
    <div
      style={{
        position: 'absolute',
        inset: '0 0 auto 0',
        height: 52,
        display: 'flex',
        alignItems: 'center',
        gap: 30,
        padding: '0 36px',
        fontSize: 21,
        fontWeight: 500,
        color: 'rgba(255,255,255,0.88)',
        background: 'rgba(0,0,0,0.45)',
        borderBottom: '1px solid rgba(255,255,255,0.06)',
        translate: `0 ${interpolate(frame, [0, 18], [-60, 0], {...clamp, easing: easeOut})}px`,
      }}
    >
      <span style={{fontWeight: 700}}>Notes</span>
      <span>File</span>
      <span>Edit</span>
      <span>Format</span>
      <span>View</span>
      <span>Window</span>

      <div style={{position: 'absolute', left: RING.x - 17, top: 9}}>
        {ripple > 0 && ripple < 1 ? (
          <div
            style={{
              position: 'absolute',
              left: 17 - 80 * ripple,
              top: 17 - 80 * ripple,
              width: 160 * ripple,
              height: 160 * ripple,
              borderRadius: '50%',
              border: `3px solid ${EMBER}`,
              opacity: 1 - ripple,
              boxShadow: `0 0 24px ${EMBER}`,
            }}
          />
        ) : null}
        <RingLogo
          size={34}
          mode={recording ? 'ember' : 'white'}
          bars={bars}
          glow={recording ? 6 : 0}
          busyAngle={busy ? (frame - ESC_PRESS) * 16 : null}
        />
      </div>
      <span style={{position: 'absolute', left: 1630}}>
        <svg width="26" height="20" viewBox="0 0 16 12" fill="rgba(255,255,255,.85)">
          <path d="M8 11.5 5.6 8.9a3.4 3.4 0 0 1 4.8 0zM3.5 6.8a6.4 6.4 0 0 1 9 0l-1.1 1.1a4.9 4.9 0 0 0-6.8 0zM1.3 4.6a9.5 9.5 0 0 1 13.4 0l-1.1 1.1a7.9 7.9 0 0 0-11.2 0z" />
        </svg>
      </span>
      <span style={{position: 'absolute', left: 1690}}>
        <svg width="40" height="20" viewBox="0 0 24 12">
          <rect x=".5" y=".5" width="20" height="11" rx="3" fill="none" stroke="#fff" opacity=".6" />
          <rect x="2" y="2" width="14" height="8" rx="1.5" fill="#fff" />
          <rect x="21.5" y="4" width="1.5" height="4" rx=".7" fill="#fff" opacity=".6" />
        </svg>
      </span>
      <span style={{position: 'absolute', left: 1760}}>Sat 9:41</span>
    </div>
  );
};

const NoteWindow = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const enter = spring({frame: frame - 4, fps, config: {damping: 200}});

  const revealed = Math.max(0, Math.floor((frame - LAND + 2) * 4));
  const done = revealed >= SENTENCE.length;
  const blink = Math.floor(frame / 9) % 2 === 0;
  const caretVisible = revealed > 0 && !done ? true : blink;
  const flash = interpolate(frame, [LAND, LAND + 22], [0, 1], clamp);

  return (
    <MirrorPanel
      radius={26}
      sheen={interpolate(frame, [LAND + 4, LAND + 34], [-0.3, 1.3], clamp)}
      style={{
        left: NOTE.left,
        top: NOTE.top,
        width: NOTE.width,
        height: NOTE.height,
        opacity: enter,
        translate: `0 ${interpolate(enter, [0, 1], [40, 0])}px`,
      }}
    >
      <div style={{height: 66, display: 'flex', alignItems: 'center', gap: 12, padding: '0 26px', borderBottom: '1px solid rgba(255,255,255,0.06)'}}>
        {[0, 1, 2].map((i) => (
          <div key={i} style={{width: 16, height: 16, borderRadius: 8, background: '#3a3a44', boxShadow: 'inset 0 1px 0 rgba(255,255,255,.18)'}} />
        ))}
        <span style={{marginLeft: 18, fontSize: 21, fontWeight: 600, color: 'rgba(255,255,255,0.55)'}}>Meeting notes</span>
      </div>
      <div style={{padding: '38px 46px', fontSize: 34, lineHeight: 1.6, color: '#e6e6ec'}}>
        <div style={{fontWeight: 700, fontSize: 40}}>Standup — Oct 24</div>
        <div style={{color: 'rgba(255,255,255,0.55)'}}>• Design review moved to Thursday</div>
        <div>
          <span style={{color: 'rgba(255,255,255,0.55)'}}>Update: </span>
          {SENTENCE.slice(0, revealed)
            .split('')
            .map((ch, i) => {
              const age = revealed - i;
              return (
                <span key={i} style={{textShadow: age < 10 ? `0 0 ${18 - age * 1.6}px ${ICE}` : undefined, color: age < 6 ? '#ffffff' : undefined}}>
                  {ch}
                </span>
              );
            })}
          <span
            style={{
              display: 'inline-block',
              width: 3,
              height: 40,
              marginLeft: 3,
              translate: '0 8px',
              background: ICE,
              boxShadow: `0 0 10px ${ICE}`,
              opacity: caretVisible ? 1 : 0,
            }}
          />
        </div>
      </div>
      {flash > 0 && flash < 1 ? (
        <div
          style={{
            position: 'absolute',
            left: CARET.x - NOTE.left - 260 * flash,
            top: CARET.y - NOTE.top - 260 * flash,
            width: 520 * flash,
            height: 520 * flash,
            borderRadius: '50%',
            background: `radial-gradient(circle, rgba(207,230,255,${0.55 * (1 - flash)}) 0%, transparent 65%)`,
          }}
        />
      ) : null}
    </MirrorPanel>
  );
};

const Capsule = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const enter = spring({frame: frame - (CLICK + 3), fps, config: {damping: 14, stiffness: 140}});
  const exit = interpolate(frame, [FLY_START + 2, FLY_START + 26], [0, 1], {...clamp, easing: easeOut});
  if (frame < CLICK) return null;

  const sealing = frame >= ESC_PRESS;
  const count = Math.min(WORDS.length, Math.max(0, Math.floor((frame - WORDS_START) / 5) + 1));
  const finalCount = sealing ? count : Math.max(0, count - 2);
  const seconds = Math.max(0, Math.floor((Math.min(frame, ESC_PRESS) - CLICK) / 30));
  const textOpacity = interpolate(frame, [FLY_START, FLY_START + 4], [1, 0], clamp);

  return (
    <MirrorPanel
      radius={36}
      sheen={interpolate(frame, [CLICK + 20, CLICK + 60], [-0.3, 1.3], clamp)}
      style={{
        left: CAPSULE.left,
        top: CAPSULE.top,
        width: CAPSULE.width,
        padding: '24px 30px 22px',
        transformOrigin: '70% 0%',
        opacity: enter * (1 - exit),
        scale: `${interpolate(enter, [0, 1], [0.85, 1]) * interpolate(exit, [0, 1], [1, 0.94])}`,
        translate: `0 ${interpolate(enter, [0, 1], [-30, 0])}px`,
        filter: `blur(${exit * 10}px)`,
      }}
    >
      <div style={{display: 'flex', alignItems: 'center', gap: 12, fontSize: 17, fontWeight: 600, letterSpacing: '0.16em', color: 'rgba(255,255,255,0.5)'}}>
        <div
          style={{
            width: 11,
            height: 11,
            borderRadius: 6,
            background: EMBER,
            boxShadow: `0 0 14px ${EMBER}`,
            opacity: 0.55 + 0.45 * Math.sin(frame * 0.25),
          }}
        />
        {sealing ? 'SEALING' : 'LISTENING'}
        <span style={{marginLeft: 'auto', letterSpacing: '0.06em', fontVariantNumeric: 'tabular-nums'}}>0:0{seconds}</span>
      </div>
      <div style={{margin: '10px 0 6px'}}>
        <Waveform width={CAPSULE.width - 60} height={92} level={levelAt(frame)} phase={frame * 0.12 * 3.6} />
      </div>
      <div style={{fontSize: 30, lineHeight: 1.42, minHeight: 128, opacity: textOpacity}}>
        <span style={silverText}>{WORDS.slice(0, finalCount).join(' ')} </span>
        <span style={{color: 'rgba(255,255,255,0.32)'}}>{WORDS.slice(finalCount, count).join(' ')}</span>
      </div>
      <div style={{marginTop: 14, display: 'flex', justifyContent: 'space-between', fontSize: 17, color: 'rgba(255,255,255,0.4)'}}>
        <span>→ Notes · Meeting notes</span>
        <span>esc or click ◎ to finish</span>
      </div>
    </MirrorPanel>
  );
};

/** The transcript lifts out of the capsule and pours into the caret, with ghost trails for motion blur. */
const FlyingText = () => {
  const frame = useCurrentFrame();
  if (frame < FLY_START || frame > LAND + 2) return null;

  const start = {x: CAPSULE.left + CAPSULE.width / 2, y: CAPSULE.top + 260};
  const control = {x: 980, y: 40};
  const at = (f: number) => {
    const u = interpolate(f, [FLY_START, LAND], [0, 1], {...clamp, easing: easeInOut});
    const x = (1 - u) ** 2 * start.x + 2 * (1 - u) * u * control.x + u ** 2 * CARET.x;
    const y = (1 - u) ** 2 * start.y + 2 * (1 - u) * u * control.y + u ** 2 * CARET.y;
    return {u, x, y};
  };

  const ghosts = [3, 2, 1, 0];
  return (
    <>
      {ghosts.map((k) => {
        const p = at(frame - k * 1.2);
        const speed = Math.hypot(at(frame).x - at(frame - 1).x, at(frame).y - at(frame - 1).y);
        return (
          <div
            key={k}
            style={{
              position: 'absolute',
              left: p.x - 320,
              top: p.y - 60,
              width: 640,
              fontSize: 30,
              lineHeight: 1.42,
              textAlign: 'center',
              color: k === 0 ? '#ffffff' : ICE,
              textShadow: `0 0 24px ${ICE}`,
              opacity: (k === 0 ? 1 : 0.28 / k) * interpolate(p.u, [0, 0.82, 1], [1, 1, 0], clamp),
              scale: interpolate(p.u, [0, 1], [1, 0.08], clamp),
              filter: `blur(${Math.min(8, speed / 6)}px)`,
            }}
          >
            {SENTENCE}
          </div>
        );
      })}
    </>
  );
};

const Cursor = () => {
  const frame = useCurrentFrame();
  const u = interpolate(frame, [16, CLICK - 3], [0, 1], {...clamp, easing: easeInOut});
  const a = {x: 1060, y: 780};
  const b = {x: 1500, y: 520};
  const c = {x: RING.x + 4, y: RING.y + 6};
  const x = (1 - u) ** 2 * a.x + 2 * (1 - u) * u * b.x + u ** 2 * c.x;
  const y = (1 - u) ** 2 * a.y + 2 * (1 - u) * u * b.y + u ** 2 * c.y;
  const press = interpolate(frame, [CLICK - 3, CLICK, CLICK + 5], [1, 0.82, 1], clamp);
  const opacity = interpolate(frame, [12, 18, 92, 104], [0, 1, 1, 0], clamp);

  return (
    <svg
      width="34"
      height="48"
      viewBox="0 0 17 24"
      style={{position: 'absolute', left: x, top: y, opacity, scale: press, transformOrigin: '0 0', filter: 'drop-shadow(0 4px 8px rgba(0,0,0,0.6))'}}
    >
      <path d="M1 1 L1 19 L5.5 14.8 L8.6 22 L11.6 20.7 L8.6 13.6 L14.5 13.6 Z" fill="#fff" stroke="#000" strokeWidth="1.2" strokeLinejoin="round" />
    </svg>
  );
};

/** Screen-space caption while the camera is pushed in on the capsule. */
const LowerThird = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const inP = spring({frame: frame - 100, fps, config: {damping: 200}});
  const out = interpolate(frame, [146, 156], [1, 0], clamp);
  if (frame < 96 || frame > 160) return null;

  return (
    <div style={{position: 'absolute', left: 120, bottom: 120, opacity: inP * out}}>
      <div style={{fontSize: 22, fontWeight: 600, letterSpacing: '0.2em', color: EMBER, marginBottom: 10, translate: `${interpolate(inP, [0, 1], [-30, 0])}px 0`}}>
        LIVE TRANSCRIPTION
      </div>
      <div style={{fontSize: 64, fontWeight: 700, letterSpacing: '-0.03em', ...silverText, translate: `${interpolate(inP, [0, 1], [-60, 0])}px 0`}}>
        Words appear as you speak.
      </div>
    </div>
  );
};

const EscKey = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const enter = spring({frame: frame - 146, fps, config: {damping: 12, stiffness: 170}});
  const press = interpolate(frame, [ESC_PRESS - 3, ESC_PRESS, ESC_PRESS + 6], [0, 1, 0], clamp);
  const out = interpolate(frame, [174, 184], [1, 0], clamp);
  if (frame < 144 || frame > 186) return null;

  return (
    <div
      style={{
        position: 'absolute',
        left: 0,
        right: 0,
        bottom: 110,
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        gap: 36,
        opacity: Math.min(enter, out),
        scale: interpolate(enter, [0, 1], [0.6, 1]),
      }}
    >
      <MirrorPanel
        radius={30}
        style={{
          position: 'relative',
          width: 200,
          height: 140,
          translate: `0 ${press * 10}px`,
          boxShadow: `0 ${30 - press * 22}px ${70 - press * 40}px rgba(0,0,0,0.8), 0 0 ${press * 60}px rgba(255,90,60,${press * 0.6}), inset 0 1px 0 rgba(255,255,255,.2)`,
        }}
      >
        <div style={{position: 'absolute', left: 26, top: 22, fontSize: 46, fontWeight: 600, ...silverText}}>esc</div>
      </MirrorPanel>
      <div style={{fontSize: 46, fontWeight: 600, color: 'rgba(255,255,255,0.75)', letterSpacing: '-0.02em'}}>
        to finish <span style={{color: EMBER}}>&amp;</span> insert
      </div>
    </div>
  );
};
