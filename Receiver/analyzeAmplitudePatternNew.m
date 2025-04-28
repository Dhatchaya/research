function amplitudePattern = analyzeAmplitudePatternNew(normalizedAmplitude,fileName)
    % Main function:
    % 1. Find the preamble (10101010 pattern with high=~80, low=~0)
    % 2. Use the next 4 pulses for calibration (avg amplitudes of rising-to-falling)
    % 3. Process the remaining signal using calibrated thresholds

    % Step 1: Find preamble
    preambleEndIndex = findPreamble(normalizedAmplitude);
    if isempty(preambleEndIndex)
        error('Preamble not found.');
    end
    fprintf('Preamble found ending at index: %d\n', preambleEndIndex);

    % Step 2: Calibration - Get average amplitudes for next 4 pulses
    [calibrationThresholds, calibAmps, calibrationEndIndex] = calibrateThresholds(normalizedAmplitude, preambleEndIndex);
    fprintf('Calibration amplitudes (average values):\n');
    disp(calibAmps);
    fprintf('Calibrated thresholds (midpoints):\n');
    disp(calibrationThresholds);
   disp(['calibrationEndIndex ', num2str(calibrationEndIndex)]);
    % Calculate data length after calibration
    [dataLength,lenEndIndex] = findDataLength(normalizedAmplitude, calibrationEndIndex,calibrationThresholds);
  disp(['lenEndIndex ', num2str(lenEndIndex)]);
    % Extract data pulses
    dataSegment = normalizedAmplitude(lenEndIndex:end);
    numDataPulses = floor(dataLength / 2);  % Since each pulse represents 2 bits
    % Detect all pulses in the remaining signal
    [risingEdges, pulseAverages] = extractPulseAverages(dataSegment, numDataPulses);
    amplitudePattern = detectAmplitudes(pulseAverages, calibrationThresholds);

    fprintf('Amplitude Pattern:\n');
    disp(amplitudePattern);

    % Convert amplitude pattern to binary
    patternToBinary = amplitudeToBinary(amplitudePattern);
    fprintf('Binary Pattern:\n%s\n', patternToBinary);
   
    % Decode using Hamming (7,4)
    decodedText = hamming74_decode(patternToBinary,fileName);  % Skipping first 2 bits
    
    fprintf('Decoded Text: %s\n', decodedText);
end

function ber = calculateBER(decodedBinary, expectedBinary)
    % Ensure both inputs are binary strings of the same length
    if length(decodedBinary) ~= length(expectedBinary)
        error('Decoded and expected binary strings must be the same length');
    end
    
    % Convert binary strings to numerical arrays (0s and 1s)
    decodedBits = decodedBinary - '0';
    expectedBits = expectedBinary - '0';
    
    % Compute the number of bit errors
    numErrors = sum(decodedBits ~= expectedBits);
    
    % Compute the Bit Error Rate (BER)
    ber = numErrors / length(expectedBits);
end


%% Function to calculate data length based on next 4 peaks after calibration
function [dataLength,lenEndIndex] = findDataLength(signal, calibrationEndIndex,thresholds)
    % Extract the next 4 pulses after the calibration phase
    signalSegment = signal(calibrationEndIndex+1:end);
    [risingEdges, pulseAverages] = extractPulseAverages(signalSegment, 4);  % Get next 4 pulses
    
    % Ensure we have exactly 4 pulses
    if length(pulseAverages) < 4
        error('Not enough pulses found after calibration to determine data length.');
    end
    amplitudePattern = detectAmplitudes(pulseAverages, thresholds);

    fprintf('Amplitude Pattern:\n');
    disp(amplitudePattern);

    % Convert amplitude pattern to binary
    binaryPattern = amplitudeToBinary(amplitudePattern);
    fprintf('Binary Pattern:\n%s\n', binaryPattern);
    binaryArray = binaryPattern - '0'; 
    % Convert binary pattern to decimal to get the data length
    dataLengthDec = binaryToDecimal(binaryArray);  % Convert binary string to decimal
    % Adjust dataLength to the nearest lower multiple of 14
    dataLength = floor(dataLengthDec / 14) * 14;
    if (dataLength == 0)
        dataLength = 14;
    end

    %dataLength = dataLengthBits / 2;  % Each pulse represents 2 bits, so divide by 2
    lenEndIndex = calibrationEndIndex+1+risingEdges(4, 2);
    % Display the result
    disp(['Data Length (in pulses): ', num2str(dataLength)]);
end

function preambleEndIndex = findPreamble(signal)
    maxAmplitude = max(signal);
    expectedAmplitude = 0.5 * maxAmplitude;
    minRise = 0.01 * maxAmplitude;

    risingEdgeIndices = find(diff(signal) > minRise);

    validPulseCount = 0;
    i = 1;

    while i <= length(risingEdgeIndices) - 1
        startIdx = risingEdgeIndices(i);

        % Trace rising to peak
        peakIdx = startIdx + 1;
        while peakIdx < length(signal) && signal(peakIdx) >= signal(peakIdx - 1)
            peakIdx = peakIdx + 1;
        end

        % Trace peak down to end of falling edge
        endIdx = peakIdx;
        while endIdx < length(signal) && signal(endIdx) <= signal(endIdx - 1)
            endIdx = endIdx + 1;
        end

        % Get peak amplitude of the pulse
        peakAmp = max(signal(startIdx:endIdx));

        if peakAmp >= expectedAmplitude
            validPulseCount = validPulseCount + 1;

            if validPulseCount == 4
                preambleEndIndex = endIdx -1;  % <-- now returns falling edge end
                return;
            end

            % Skip to the next rising edge after this pulse
            while i <= length(risingEdgeIndices) && risingEdgeIndices(i) < endIdx
                i = i + 1;
            end
        else
            i = i + 1; % move to next rising edge
        end
    end

    preambleEndIndex = []; % if 4 valid pulses are not found
end


%% Function to find preamble
function preambleEndIndex = oldfindPreamble(signal)
    tolerance = 10;
    expectedPattern = [0.5, 0, 0.5, 0, 0.5, 0, 0.5, 0] * max(signal);
    preambleEndIndex = [];

    for i = 1:length(signal)-7
        segment = signal(i:i+7);
        if all(abs(segment - expectedPattern) < tolerance)
            preambleEndIndex = i + 7;
            return;
        end
    end
end

%% Function to calibrate thresholds
function [thresholds, calibAmps, calibrationEndIndex] = calibrateThresholds(signal, startIndex)
    % Find the first 4 pulses after preamble
    signalSegment = signal(startIndex+1:end);

% Plot the normalized amplitude
figure;
plot(signalSegment, 'LineWidth', 1);
xlabel('Time (s)');
ylabel('caliberate threshold');
title('caliberate threshold');
grid on;
    [risingEdges, pulseAverages] = extractPulseAverages(signalSegment, 4);

    if length(pulseAverages) < 4
        error('Not enough calibration pulses found.');
    end

        % Calibration amplitudes (average of rising-to-falling)
        calibAmps = pulseAverages(1:4);

        % Compute 4 thresholds
        thresholds(1) = (calibAmps(1) + calibAmps(2)) / 2; % Between 80 and 60
        thresholds(2) = (calibAmps(2) + calibAmps(3)) / 2; % Between 60 and 40
        thresholds(3) = (calibAmps(3) + calibAmps(4)) / 2; % Between 40 and 20
        thresholds(4) = calibAmps(4) - (calibAmps(3) - calibAmps(4)) / 2; % Below 20
    
        % End of calibration segment
        calibrationEndIndex = startIndex + risingEdges(4, 2);
end

%% Function to detect pulses and get average amplitude
function amplitudePattern = detectAmplitudes(pulseAverages, thresholds)
    
    
    amplitudePattern = [];
    for i = 1:length(pulseAverages)
        avgAmp = pulseAverages(i);
        if avgAmp >= thresholds(1)
            amplitudePattern = [amplitudePattern; 80];
        elseif avgAmp >= thresholds(2)
            amplitudePattern = [amplitudePattern; 60];
        elseif avgAmp >= thresholds(3)
            amplitudePattern = [amplitudePattern; 40];
        else
            amplitudePattern = [amplitudePattern; 20];
        end
    end
end

function [risingEdges, pulseAverages] = extractPulseAverages(signal, maxPulses)
    numSamples = length(signal);
    risingEdges = [];
    pulseAverages = [];
    rising = false;
    falling = false;
    startIdx = -1;
    pulseCount = 0;
    threshold = 0.01; % Minimum change to detect a rise/fall (tune this)
% Plot the normalized amplitude
figure;
plot(signal, 'LineWidth', 1);
xlabel('Time (s)');
ylabel('signal');
title('signal');
grid on;

    for i = 2:numSamples - 1
           disp(['signal ', num2str(i),num2str(signal(i)),  num2str(signal(i-1)), num2str(signal(i+1))]);
        % Detect rising edge (start of a pulse)
        if (signal(i) - signal(i - 1)) > threshold && ~rising && ~falling
            disp("rise");
            rising = true;
            startIdx = i - 1;
        end

        % Detect peak (end of rising, start of falling)
      if rising && (signal(i) - signal(i + 1)) >= threshold
             disp("fall");
            rising = false;
            falling = true;
        end

        % Detect end of falling edge (pulse end)
        if falling && (signal(i + 1) - signal(i))>threshold
             disp("pulse end");
            endIdx = i;
            falling = false;  % Reset state

            % Compute the average amplitude over the full pulse (rising + falling)
            pulseSegment = signal(startIdx:endIdx);
            avgAmp = mean(pulseSegment);

            % Store results
            risingEdges = [risingEdges; startIdx, endIdx];
            pulseAverages = [pulseAverages; avgAmp];

            % Increment pulse count and stop if maxPulses reached
            pulseCount = pulseCount + 1;
            if pulseCount >= maxPulses
                    disp('risingEdges: ');
disp(risingEdges);
   disp('pulseAverages: ');
disp(pulseAverages);
                return;
            end
        end
    end

end


%% Function to map amplitudes to binary
function binaryString = amplitudeToBinary(amplitudeArray)
    binaryString = '';
    for i = 1:length(amplitudeArray)
        switch amplitudeArray(i)
            case 80
                binaryString = [binaryString, '10'];
            case 60
                binaryString = [binaryString, '11'];
            case 40
                binaryString = [binaryString, '01'];
            case 20
                binaryString = [binaryString, '00'];
            otherwise
                error('Unexpected amplitude value: %d', amplitudeArray(i));
        end
    end
end

%% Hamming (7,4) Decoding Functions
function decodedText = hamming74_decode(encodedBinary,fileName)
    if mod(length(encodedBinary), 7) ~= 0
        error('Encoded binary string length must be a multiple of 7');
    end
    
    decodedBits = [];
    numCodewords = length(encodedBinary) / 7;

    for i = 1:numCodewords
        codeword = encodedBinary((i-1)*7 + 1 : i*7) - '0';
        correctedData = correctHamming74(codeword);
        decodedBits = [decodedBits, correctedData];
    end
          referenceBinary = filenameToBinary(fileName);
       disp(['reference Binary: ', referenceBinary]);     
     %referenceBinary = '0100001001100101';
       decodedBitsStr = num2str(decodedBits);
       decodedBitsStr(isspace(decodedBitsStr)) = [];  % Remove spaces
        fprintf('Decoded bits: %s\n', decodedBitsStr);
      if(length(referenceBinary)<length(decodedBitsStr))
            % Trim extractedBinary to match the length of referenceBinary
        decodedBitsStr = decodedBitsStr(1:length(referenceBinary));
      end
      if (length(referenceBinary)> length(decodedBitsStr))
        referenceBinary = referenceBinary(1:length(decodedBitsStr));
      end
     BER = calculateBER(decodedBitsStr,referenceBinary);
     
      fprintf('BER: %s\n', BER);
      disp(BER);
    decodedText = binaryToAscii(decodedBits);
end

function correctedData = correctHamming74(codeword)
    H = [1 0 1 0 1 0 1; 
         0 1 1 0 0 1 1; 
         0 0 0 1 1 1 1];

    syndrome = mod(codeword * H', 2);
    errorIndex = binaryToDecimal(flip(syndrome));

    if errorIndex > 0
        fprintf('Error detected at position %d. Correcting...\n', errorIndex);
        codeword(errorIndex) = mod(codeword(errorIndex) + 1, 2);
    end
    correctedData = [codeword(3), codeword(5), codeword(6), codeword(7)];
end

function decimalValue = binaryToDecimal(binaryArray)
    decimalValue = sum(binaryArray .* 2.^(length(binaryArray)-1:-1:0));
end

function asciiText = binaryToAscii(binaryData)
    asciiText = '';
    numChars = floor(length(binaryData) / 8);
    for i = 1:numChars
        byte = binaryData((i-1)*8 + 1 : i*8);
        asciiValue = binaryToDecimal(byte);
        asciiText = [asciiText, char(asciiValue)];
    end
end
function binaryString = filenameToBinary(filename)
    % Extract the name part before '.mat'
    [~, name, ~] = fileparts(filename);
    
    % Initialize an empty string to hold the binary representation
    binaryString = '';
    disp(name);
    % Loop through each character in the name
    for i = 1:length(name)
        % Convert the character to its ASCII value
        asciiValue = double(name(i));
        
        % Convert the ASCII value to an 8-bit binary string
        binaryChar = dec2bin(asciiValue, 8);
        
        % Append to the binary string
        binaryString = strcat(binaryString, binaryChar);
    end
end