import type {CSSProperties, ReactNode} from 'react';

type Props = {
  readonly radius: number;
  readonly style?: CSSProperties;
  readonly children?: ReactNode;
  /** -1..2, position of the diagonal specular sweep (off-panel outside 0..1). */
  readonly sheen?: number;
};

/** Black glass with a chrome rim: the "dark mirror" surface used everywhere in Murmur. */
export const MirrorPanel = ({radius, style, children, sheen = -1}: Props) => (
  <div
    style={{
      position: 'absolute',
      borderRadius: radius,
      background: 'linear-gradient(180deg, rgba(30,30,40,0.88), rgba(7,7,11,0.94))',
      boxShadow: '0 50px 140px rgba(0,0,0,0.75), inset 0 1px 0 rgba(255,255,255,0.16), inset 0 -1px 0 rgba(255,255,255,0.04)',
      overflow: 'hidden',
      ...style,
    }}
  >
    {children}
    <div
      style={{
        position: 'absolute',
        inset: 0,
        borderRadius: radius,
        padding: 1.5,
        background:
          'linear-gradient(160deg, rgba(255,255,255,0.45), rgba(255,255,255,0.06) 35%, rgba(255,255,255,0.02) 65%, rgba(255,255,255,0.22))',
        WebkitMask: 'linear-gradient(#000 0 0) content-box, linear-gradient(#000 0 0)',
        WebkitMaskComposite: 'xor',
        maskComposite: 'exclude',
        pointerEvents: 'none',
      }}
    />
    <div
      style={{
        position: 'absolute',
        inset: 0,
        pointerEvents: 'none',
        background: `linear-gradient(115deg, transparent ${sheen * 100 - 18}%, rgba(255,255,255,0.09) ${sheen * 100}%, transparent ${sheen * 100 + 18}%)`,
      }}
    />
  </div>
);
