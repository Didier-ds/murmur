import {Audio} from '@remotion/media';
import {linearTiming, springTiming, TransitionSeries} from '@remotion/transitions';
import {slide} from '@remotion/transitions/slide';
import {AbsoluteFill, useVideoConfig} from 'remotion';
import {Backdrop, Grain} from './components/Atmosphere';
import {Anywhere} from './scenes/Anywhere';
import {Desktop} from './scenes/Desktop';
import {EndCard} from './scenes/EndCard';
import {Intro} from './scenes/Intro';
import {ZoomThroughPresentation} from './ZoomThrough';

// Scene lengths (frames at 30 fps) and the overlaps their transitions create:
// Intro 90 + Desktop 240 + Anywhere 100 + EndCard 59 − (15 + 12 + 12) = 450 frames = 15 s.
// Global start frames: Intro 0, Desktop 75, Anywhere 303, EndCard 391.
export const MurmurPromo = () => {
  const {fps} = useVideoConfig();

  return (
    <AbsoluteFill style={{backgroundColor: '#050507'}}>
      <Backdrop />

      <TransitionSeries>
        <TransitionSeries.Sequence name="Intro" durationInFrames={90}>
          <Intro />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition
          presentation={{component: ZoomThroughPresentation, props: {}}}
          timing={linearTiming({durationInFrames: 15})}
        />
        <TransitionSeries.Sequence name="Desktop demo" durationInFrames={240}>
          <Desktop />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition
          presentation={slide({direction: 'from-right'})}
          timing={springTiming({config: {damping: 200}, durationInFrames: 12})}
        />
        <TransitionSeries.Sequence name="Anywhere" durationInFrames={100}>
          <Anywhere />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition
          presentation={{component: ZoomThroughPresentation, props: {}}}
          timing={linearTiming({durationInFrames: 12})}
        />
        <TransitionSeries.Sequence name="End card" durationInFrames={59}>
          <EndCard />
        </TransitionSeries.Sequence>
      </TransitionSeries>

      <Grain />

      {/* Sound design */}
      <Audio name="Ring whoosh" src="https://remotion.media/whoosh.wav" volume={0.45} />
      <Audio name="Zoom through" from={70} src="https://remotion.media/whoosh.wav" volume={0.6} />
      <Audio name="Click" from={75 + 55} src="https://remotion.media/mouse-click.wav" volume={0.9} />
      <Audio name="Esc press" from={75 + 162} src="https://remotion.media/switch.wav" volume={0.8} />
      <Audio name="Text lands" from={75 + 206} src="https://remotion.media/ding.wav" volume={0.35} />
      <Audio name="Beat 1" from={300} src="https://remotion.media/whip.wav" volume={0.5} />
      <Audio name="Beat 2" from={303 + 30} src="https://remotion.media/whoosh.wav" volume={0.35} />
      <Audio name="Beat 3" from={303 + 60} src="https://remotion.media/whoosh.wav" volume={0.35} />
      <Audio name="End card" from={391} src="https://remotion.media/whoosh.wav" volume={0.5} durationInFrames={2 * fps} />
    </AbsoluteFill>
  );
};
