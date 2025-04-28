function [radarCube] = getTargetSignal(radarCube)

% extract slow time samples for each range bin: the complex values of target
% range FFT bin across all chirps

% output: radarCube
%               + targetSignal

DopplerBin = radarCube.rfParams.numDopplerBins;
rangeBin = radarCube.rfParams.numRangeBins;
NFrame = radarCube.dim.numFrames;
NRxChan = radarCube.dim.numRxChan;


targetN = rangeBin;



for idx=1:targetN

    rangeIdx = idx;
    DataArray = NaN(DopplerBin+2,NFrame,NRxChan);

    for frameIdx = 1:NFrame

        frameData = radarCube.data_rangeFFT{frameIdx};

        for chIdx = 1:NRxChan

            DataArray(1:DopplerBin,frameIdx,chIdx) = frameData(:,rangeIdx,chIdx);

        end
    end


    for chIdx = 1:NRxChan

        temp = DataArray(:,:,chIdx);

        targetSignal(:,chIdx) = temp(:);

    end

    radarCube.targetSignal(:,:,idx)=targetSignal;


end
end


