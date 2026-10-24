import type {TransitionPresentationComponentProps} from '@remotion/transitions';
import {AbsoluteFill, interpolate} from 'remotion';

/** The outgoing scene rushes toward the camera and dissolves; the incoming one settles in from slightly behind. */
export const ZoomThroughPresentation = ({
  children,
  presentationDirection,
  presentationProgress: p,
}: TransitionPresentationComponentProps<Record<string, never>>) => {
  if (presentationDirection === 'exiting') {
    return (
      <AbsoluteFill
        style={{
          scale: interpolate(p, [0, 1], [1, 2.6]),
          opacity: interpolate(p, [0, 0.7], [1, 0], {extrapolateRight: 'clamp'}),
          filter: `blur(${interpolate(p, [0, 1], [0, 18])}px)`,
        }}
      >
        {children}
      </AbsoluteFill>
    );
  }
  return (
    <AbsoluteFill
      style={{
        scale: interpolate(p, [0, 1], [0.86, 1]),
        opacity: interpolate(p, [0.2, 1], [0, 1], {extrapolateLeft: 'clamp'}),
        filter: `blur(${interpolate(p, [0, 1], [10, 0])}px)`,
      }}
    >
      {children}
    </AbsoluteFill>
  );
};
