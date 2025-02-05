function  [vibSig]=getVibSig(signal,ang,sigFre)

fontsize = 16;
fig_width = 15;
fig_height = 12;
linewidth = 2.5;

[Nsample,NRx] = size(signal);
Nchirp = 130;
fs=10000;
fft_x  =fs/(Nsample-1)*(0:1:Nsample-1);

% filter
filter_fft = zeros(1,Nsample);
sig_st = find(fft_x>=sigFre(1),1);
sig_end = find(fft_x>sigFre(2),1);
sigIdx = sig_st:1:sig_end;
filter_fft(sigIdx)=1;
filter_fft = filter_fft';


% beamforming
w = pi* sin(ang/180*pi);
signal_beam = signal(:,1)+ signal(:,2)*exp(-1i*w)+signal(:,3)*exp(-1i*2*w)+signal(:,4)*exp(-1i*3*w);

%outliter
loc_0  = find(signal_beam==complex(0));
signal_beam(loc_0)=  nan;

signal_beam = fillmissing(signal_beam,'linear');



freBand = abs(fft(signal_beam));
%freBand(3585:-256:0,:) = freBand(3585+1:-256:0,:) ;


figure;
set(gcf,'unit', 'centimeters', 'position', [15,10,fig_width,fig_height],'DefaultTextFontName','times new roman','Color',[1 1 1]);
 %plot(fft_x,abs(fft(signal_beam)));
plot(fft_x,freBand);
xlim([100,300]);
set(gca, 'fontsize', fontsize);
set(gca,'YDir','normal');
xlabel('Frequency(Hz)','FontSize',fontsize); ylabel('|FFT|','FontSize',fontsize);
title('FFT on Phase ','FontSize',fontsize);


vibSig = getPhase(signal_beam,filter_fft);
max_amplitude = max(vibSig);
min_amplitude = min(vibSig);
peak_to_peak_amplitude = max_amplitude - min_amplitude;
fprintf("Amplitude %d",peak_to_peak_amplitude);
figure;
set(gcf,'unit', 'centimeters', 'position', [15,10,fig_width,fig_height],'DefaultTextFontName','times new roman','Color',[1 1 1]);
plot(vibSig);
ylim([-0.2,0.2]);
xlim([100,30000+100]);
set(gca, 'fontsize', fontsize);
set(gca,'YDir','normal');
xlabel('#Sample','FontSize',fontsize); ylabel('Phase(rad)','FontSize',fontsize);
title('Phase','FontSize',fontsize);


% Set up parameters
time_interval_ms = 100;
sample_interval = (time_interval_ms / 1000) * fs; % 2000 samples
start_sample = 2500; % Starting sample index
end_sample = 36000;

% Calculate time in seconds
start_time = start_sample / fs; % Starting time in seconds
end_time = end_sample / fs;     % Ending time in seconds
time_interval_sec = sample_interval / fs; % Interval in seconds


total_samples = length(vibSig);
time_axis = (0:total_samples - 1) / fs; % Convert samples to seconds

% Set up the phase plot
figure;
set(gcf, 'unit', 'centimeters', 'position', [15, 10, fig_width, fig_height], ...
    'DefaultTextFontName', 'times new roman', 'Color', [1 1 1]);
plot(time_axis, vibSig); % Plot using the full time axis
ylim([-0.1, 0.1]);
xlim([start_sample / fs, end_sample / fs]); % Specify x-axis range in seconds

% Set x-axis ticks to 200 ms intervals in seconds
xticks(start_sample / fs:time_interval_sec:end_sample / fs);

% Set other plot properties
set(gca, 'fontsize', fontsize);
set(gca, 'YDir', 'normal');
xlabel('Time (s)', 'FontSize', fontsize);
ylabel('Phase (rad)', 'FontSize', fontsize);
title('Phase', 'FontSize', fontsize);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Add grid
grid on;

windows = 128*3;

f_len = windows/2 + 1;
f = linspace(0, 500, f_len);
noverlap = windows/2;

[s,f,t,p] = spectrogram(vibSig, windows,noverlap,f,fs);

s = (abs(s));

% Normalizing amplitude across the frequency axis
amplitude_sum = sum(s, 1); % Sum over frequency (rows of s)
normalized_amplitude = amplitude_sum / max(amplitude_sum); % Normalize to [0, 1]

startId = find(t >= 0.3, 1, 'first'); % Closest index to 0.2 seconds
endId = find(t <= 3.2, 1, 'last');
disp("startid "+startId+"endid"+endId);
normalized_amplitude(1:startId) = 0;      % Zero out before startIdx
normalized_amplitude(endId+1:end) = 0;   % Zero out after endIdx

% Plot the normalized amplitude
figure;
plot(normalized_amplitude, 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Normalized Amplitude');
title('Normalized Amplitude vs Time');
grid on;

% Compute the power for each time step
power_over_time = sum(abs(s).^2, 1); % Sum power across frequencies (rows of s)

% Normalize the power over time
normalized_power_over_time = power_over_time / max(power_over_time);
startId = find(t >= 0.3, 1, 'first'); % Closest index to 0.2 seconds
endId = find(t <= 3.2, 1, 'last');
disp("startid "+startId+"endid"+endId);
normalized_power_over_time(1:startId) = 0;      % Zero out before startIdx
normalized_power_over_time(endId+1:end) = 0;   % Zero out after endIdx
disp("max amplitude is this "+max(normalized_power_over_time)*0.8);
%time = (0:length(normalized_power_over_time)-1) / fs;
% Plot the normalized power over time
figure;
plot(t,normalized_power_over_time, 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Normalized Power');
title('Power vs Time');
grid on;

detectAmplitudePattern(normalized_amplitude, fs);



figure;
set(gcf,'unit', 'centimeters', 'position', [15,10,fig_width,fig_height],'DefaultTextFontName','times new roman','Color',[1 1 1]);
imagesc(t, f, s);
set(gca, 'fontsize', fontsize);
set(gca,'YDir','normal');
xlabel('Time(s)','FontSize',fontsize); ylabel('Freqency','FontSize',fontsize);
title('Spectrum','FontSize',fontsize);
% imagesc(t, f, s);xlabel('Samples'); ylabel('Freqency');
% colorbar;



end

function phase = getPhase(signal,filter_fft)

rawPhase = angle(signal);

rawPhase = unwrap(rawPhase);
rawPhase = unwrap(rawPhase,pi);

baseline = rawPhase(1)+pi;

rawPhase(rawPhase>=baseline) = rawPhase(rawPhase>=baseline)-2*pi;


rawPhase = detrend(rawPhase);
%% filter
phase_fft =  fft(rawPhase);


phase_fft = phase_fft.*filter_fft;


phase = ifft(phase_fft,'symmetric');
phase = unwrap(phase);



phase = filloutliers(phase,'previous','mean');

phase = fillmissing(phase,'linear');


end

function amplitudePattern = detectAmplitudePattern(normalized_power_over_time, fs)
    % Define threshold levels and corresponding amplitude values
    thresholds = [0.7, 0.5, 0.29, 0.1] * max(normalized_power_over_time);
    amplitudeValues = [80, 50, 30, 10];  
    minPulseWidth = 2; % Minimum pulse width in samples

    allSegments = [];
    segmentThresholds = [];
    
    % Process each threshold level
    baseIndex = find(normalized_power_over_time >= thresholds(1), 1); % Starting index for comparison
    for i = 1:length(thresholds)
        % Find pulse indices between current and previous thresholds
        if i == 1
            indices = find(normalized_power_over_time >= thresholds(i));
        else
            indices = find(normalized_power_over_time(baseIndex:end) >= thresholds(i) & normalized_power_over_time(baseIndex:end) < thresholds(i - 1));
            indices = indices + baseIndex - 1; % Adjust indices to match full signal
        end
        disp('amplitude')
        disp( amplitudeValues(i))

        % Get segments using pulse segmentation logic
        segments = pulseSegment(indices, minPulseWidth);

        % Store segments and corresponding amplitude values
        for j = 1:size(segments, 1)
            allSegments = [allSegments; segments(j, :)];
            segmentThresholds = [segmentThresholds; amplitudeValues(i)];
        end
    end

     % Order segments by starting index
    [~, sortedIndices] = sort(allSegments(:, 1));
    allSegments = allSegments(sortedIndices, :);
    segmentThresholds = segmentThresholds(sortedIndices);
    disp(allSegments);
    % Merge segments based on the gap condition
    mergedAmplitudes = [];
    i = 1;

    while i <= size(allSegments, 1)
        currentSegment = allSegments(i, :);
        currentAmplitude = segmentThresholds(i);
        j = i + 1;

        while j <= size(allSegments, 1)
            nextSegment = allSegments(j, :);
            nextAmplitude = segmentThresholds(j);
            fprintf('next segment');
            disp(nextSegment);
            disp(currentSegment);
            % Check gap condition
            gap = nextSegment(1) - currentSegment(2);
            if gap < 3 || gap > 6
                fprintf('yes');
                % Retain the segment with the higher amplitude
                if currentAmplitude >= nextAmplitude
                    j = j + 1; % Skip smaller amplitude
                    break;
                else
                    currentSegment = nextSegment;
                    currentAmplitude = nextAmplitude;
                    j = j + 1;
                    break;
                end
            else
                fprintf('no');
                break;
            end
        end

        % Store the retained amplitude
        mergedAmplitudes = [mergedAmplitudes; currentAmplitude];
        disp('mergedAmplitudes');
        disp(mergedAmplitudes);
        i = j;
    end

    amplitudePattern = mergedAmplitudes;

    disp('Amplitude Pattern Detected:');
    disp(amplitudePattern);
end

