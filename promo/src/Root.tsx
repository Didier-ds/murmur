import {Composition} from 'remotion';
import {MurmurPromo} from './MurmurPromo';

export const RemotionRoot: React.FC = () => {
  return (
    <Composition id="MurmurPromo" component={MurmurPromo} durationInFrames={450} fps={30} width={1920} height={1080} />
  );
};
