import initCompareSelector from '~/projects/compare';
import { createRapidDiffsApp } from '~/rapid_diffs';

initCompareSelector();

const app = createRapidDiffsApp();
app.init();
