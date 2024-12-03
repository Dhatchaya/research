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


