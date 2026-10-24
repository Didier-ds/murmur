import {Composition, Still} from 'remotion';
import {MurmurPromo} from './MurmurPromo';
import {ReadmeHero} from './ReadmeHero';

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition id="MurmurPromo" component={MurmurPromo} durationInFrames={450} fps={30} width={1920} height={1080} />
      <Still id="ReadmeHero" component={ReadmeHero} width={1280} height={640} />
    </>
  );
};
