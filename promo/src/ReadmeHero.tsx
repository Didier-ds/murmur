import {AbsoluteFill} from 'remotion';
import {Backdrop, Grain} from './components/Atmosphere';
import {MirrorPanel} from './components/Mirror';
import {RingLogo} from './components/RingLogo';
import {Waveform} from './components/Waveform';
import {EMBER, fontFamily, silverText} from './theme';

const PILLS = ['On-device', 'Private', 'Any app', 'Open source'];

/** 1280×640 banner for the README and GitHub's social preview. */
export const ReadmeHero = () => (
  <AbsoluteFill style={{fontFamily, color: '#e9e9ef'}}>
    <Backdrop />

    {/* Left: brand */}
    <div style={{position: 'absolute', left: 84, top: 172, width: 560}}>
      <div style={{display: 'flex', alignItems: 'center', gap: 26}}>
        <RingLogo size={104} glow={10} sheen={0.55} />
        <div style={{fontSize: 112, fontWeight: 800, letterSpacing: '-0.05em', lineHeight: 1, ...silverText}}>Murmur</div>
      </div>
      <div style={{marginTop: 30, fontSize: 38, fontWeight: 600, letterSpacing: '-0.02em', color: 'rgba(255,255,255,0.88)'}}>
        Speak anywhere on your Mac.
      </div>
      <div style={{marginTop: 12, fontSize: 22, lineHeight: 1.45, color: 'rgba(255,255,255,0.5)'}}>
        Click the ring in the menu bar, talk, press <span style={{color: 'rgba(255,255,255,0.85)', fontWeight: 600}}>esc</span>. Your words land in
        whatever you were typing in.
      </div>
      <div style={{display: 'flex', gap: 10, marginTop: 30}}>
        {PILLS.map((pill) => (
          <div
            key={pill}
            style={{
              padding: '8px 16px',
              borderRadius: 999,
              fontSize: 17,
              fontWeight: 600,
              color: 'rgba(255,255,255,0.8)',
              background: 'rgba(255,255,255,0.05)',
              border: '1px solid rgba(255,255,255,0.12)',
            }}
          >
            {pill}
          </div>
        ))}
      </div>
    </div>

    {/* Right: the capsule, mid-dictation */}
    <div style={{position: 'absolute', left: 690, top: 172, width: 520, height: 330, perspective: 1400}}>
      <MirrorPanel
        radius={32}
        sheen={0.35}
        style={{inset: 0, padding: '22px 26px 20px', rotate: 'y -10deg'}}
      >
        <div style={{display: 'flex', alignItems: 'center', gap: 10, fontSize: 14, fontWeight: 600, letterSpacing: '0.16em', color: 'rgba(255,255,255,0.5)'}}>
          <div style={{width: 10, height: 10, borderRadius: 5, background: EMBER, boxShadow: `0 0 12px ${EMBER}`}} />
          LISTENING
          <span style={{marginLeft: 'auto', letterSpacing: '0.06em'}}>0:04</span>
        </div>
        <div style={{margin: '10px 0 4px'}}>
          <Waveform width={468} height={86} level={0.85} phase={2.2} />
        </div>
        <div style={{fontSize: 24, lineHeight: 1.45, minHeight: 104}}>
          <span style={silverText}>Ship the onboarding flow by Friday, and loop in design for the </span>
          <span style={{color: 'rgba(255,255,255,0.32)'}}>final review</span>
        </div>
        <div style={{marginTop: 12, display: 'flex', justifyContent: 'space-between', fontSize: 14, color: 'rgba(255,255,255,0.4)'}}>
          <span>→ Notes · Meeting notes</span>
          <span>esc or click ◎ to finish</span>
        </div>
      </MirrorPanel>
    </div>

    {/* Menu bar hint above the capsule */}
    <div
      style={{
        position: 'absolute',
        left: 690,
        top: 106,
        width: 520,
        height: 40,
        borderRadius: 12,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'flex-end',
        gap: 22,
        padding: '0 18px',
        fontSize: 15,
        color: 'rgba(255,255,255,0.8)',
        background: 'rgba(255,255,255,0.04)',
        border: '1px solid rgba(255,255,255,0.07)',
      }}
    >
      <RingLogo size={22} mode="ember" glow={5} bars={[0.8, 1.3, 0.7]} />
      <span style={{opacity: 0.6}}>Sat 9:41</span>
    </div>

    <Grain />
  </AbsoluteFill>
);
