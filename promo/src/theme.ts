import type {CSSProperties} from 'react';
import {Easing} from 'remotion';
import {loadFont} from '@remotion/google-fonts/Inter';

export const {fontFamily} = loadFont('normal', {
  weights: ['400', '500', '600', '700', '800'],
  subsets: ['latin'],
});

export const EMBER = '#ff5a3c';
export const ICE = '#cfe6ff';

export const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;
export const easeOut = Easing.bezier(0.16, 1, 0.3, 1);
export const easeInOut = Easing.bezier(0.65, 0, 0.35, 1);

/** Brushed-silver text, the house style for headlines. */
export const silverText: CSSProperties = {
  backgroundImage: 'linear-gradient(180deg, #ffffff 0%, #d4d7df 50%, #8a8e9a 100%)',
  WebkitBackgroundClip: 'text',
  backgroundClip: 'text',
  color: 'transparent',
};
