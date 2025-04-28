function  [decodedText]=onoffkeying(binarySignal,threshold,fs,fileName)
  pulseDurationMs = 40;
  preambleDuration = 40; %change to 50
  %binarySignal(214) = 0;
  %binarySignal(67:69)=0;
  pulseWidth = round((pulseDurationMs / 1000) * fs);
  preambleWidth =  round((preambleDuration / 1000) * fs);
  dataLengthBits = 8;
  dataLengthSize = dataLengthBits * pulseWidth;
  disp(['pulseWidth: ', num2str(pulseWidth)]);
  
  [preambleEnd]  = detectPreamblePattern(binarySignal,preambleWidth);
  disp(['preamble End: ', num2str(preambleEnd)]);

  % Get data length
  dataLengthSamples = binarySignal(preambleEnd + 1 : preambleEnd + dataLengthSize + pulseWidth);
  [datalength , dataStart] = getLength(dataLengthSamples,pulseWidth);
  
  %signalStart = preambleEnd + dataLengthSize + 1 ;
  signalStart = preambleEnd + dataStart ;
  %signalStart = 130;
   
  extractedBinary = extractBinaryFromSignal(binarySignal, signalStart, datalength, pulseWidth);
    
  [decodedText,decodedBits] = hamming74_decode(extractedBinary);

  disp(['Decoded Text: ', decodedText]);
  decodedBitsStr = num2str(decodedBits);
decodedBitsStr(isspace(decodedBitsStr)) = [];  % Remove spaces
  % Define the reference binary string
    %referenceBinary = '0100100101101110';
            referenceBinary = filenameToBinary(fileName);
       disp(['reference Binary: ', referenceBinary]);            

    if(length(referenceBinary)<length(decodedBitsStr))
            % Trim extractedBinary to match the length of referenceBinary
        decodedBitsStr = decodedBitsStr(1:length(referenceBinary));
    end
     if (length(referenceBinary)> length(decodedBitsStr))
        referenceBinary = referenceBinary(1:length(decodedBitsStr));
     end
     disp(['decoded binary: ', decodedBitsStr]);
     
     
    % Calculate BER
    BER = calculateBER(decodedBitsStr, referenceBinary);

 disp(['BER ', num2str(BER)]);
end
function [preambleEnd] = newdetectPreamblePattern(smoothedSignal, preambleWidth)
    % Define the preamble pattern
    basePattern = [1 0 1 0 1 0 1 0];  

    % Repeat the base pattern based on preambleWidth
    preambleSamples = repmat(basePattern, preambleWidth, 1);  
    preambleSamples = preambleSamples(:)';  % Flatten to 1D
    
    smoothedSignal = double(smoothedSignal);  

    % Perform cross-correlation
    correlation = xcorr(smoothedSignal, preambleSamples);

    % Find the index of the maximum correlation value
    [~, maxIdx] = max(correlation);  

    % Calculate the preamble start position
    midIdx = ceil(length(correlation) / 2);  % Midpoint of the correlation result
    preambleStart = maxIdx - midIdx + 1;  % Adjust for the midpoint offset
    
    % Calculate the preamble end position
    preambleEnd = preambleStart + length(preambleSamples);

    % Display results
    disp(['Detected preamble start index: ', num2str(preambleStart)]);
    disp(['Detected preamble end index: ', num2str(preambleEnd)]);
    disp(['Preamble Length ', num2str(length(preambleSamples))]);
end

function [preambleEnd]  = detectPreamblePattern(smoothedSignal,preambleWidth)
    % Define the preamble pattern
    basePattern = [1 0 1 0 1 0 1 0];  
   % basePattern = [1];
    %disp(smoothedSignal);
    
    % Repeat each element of the base pattern fs times
    preambleSamples = repmat(basePattern, preambleWidth, 1);  
    preambleSamples = preambleSamples(:)'; 
    smoothedSignal = double(smoothedSignal);  
    %disp(preambleSamples);
    % Perform cross-correlation
    correlation = xcorr(smoothedSignal, preambleSamples);

    % Normalize correlation
    %expectedMaxCorrelation = sum(preambleSamples .* preambleSamples);  
    %correlation = correlation / expectedMaxCorrelation;

    % Set correlation threshold (adjustable)
    correlationThreshold = max(correlation) * 0.8;

    % Find all indices where correlation exceeds the threshold
    matchIndices = find(correlation > correlationThreshold);

    % Center index of correlation (for proper alignment)
    midIdx = ceil(length(correlation) / 2);
    matchPositions = matchIndices - (midIdx - 1);
   % disp(matchPositions);

    % Minimum match count (90% of pattern length)
    preambleLength = length(preambleSamples);
    minMatchCount = ceil(0.8 * preambleLength);
    disp('min match count')
    disp(minMatchCount);
    % Explicitly initialize as an empty 3-column matrix
    detectedPreambles = zeros(0, 3);  

    % Iterate over all detected positions
    for i = 1:length(matchPositions)
        idx = matchPositions(i); % Ensure it's a scalar

        % Ensure index is within signal range
        if idx > 0 && (idx + preambleLength - 1) <= length(smoothedSignal)
            % Extract the segment from smoothedSignal
            segment = smoothedSignal(idx : idx + preambleLength - 1);
            
            % Count number of matching bits
            matchCount = sum(segment == preambleSamples);
                    %disp(['matchCount ', num2str(matchCount),'matchPositions', num2str(idx)]);
            % Check if it meets the minimum match count
            if matchCount >= minMatchCount
                startIdx = idx;
                endIdx = idx + preambleLength - 1; 

                %  Ensure row format is correct before appending
                newRow = [startIdx, endIdx, matchCount];

                %  Check size before appending
                if size(newRow, 2) == 3  % Ensure 3 columns
                    detectedPreambles = [detectedPreambles; newRow];  
                else
                    disp('Error: Mismatched column count in newRow');
                end

            end
        end
    end
    % If no valid match was found
    if isempty(detectedPreambles)
        disp('Pattern NOT detected.');
        preambleEnd = matchPositions(1) +  preambleLength - 1; 
    else
        disp('Detected preambles:');
        disp(detectedPreambles);
          % Find the row with the maximum matchCount
        [~, maxIdx] = max(detectedPreambles(:, 3));  % Find the index of the max matchCount
        maxStartIdx = detectedPreambles(maxIdx, 1);  % Get the start index
        maxEndIdx = detectedPreambles(maxIdx, 2);    % Get the end index
        
        % Display the result
        disp(['The preamble with maximum match count detected:']);
        disp(['Start Index: ', num2str(maxStartIdx)]);
        disp(['End Index: ', num2str(maxEndIdx)]);
        disp(['Match Count: ', num2str(detectedPreambles(maxIdx, 3))]);
        disp(['Preamble Length ', num2str(preambleLength)]);

        preambleEnd = maxEndIdx;
        %remove this if needed
        preambleEnd = maxStartIdx + preambleLength;
  
    end
    
end
function [binarylength] = getLengthlatest(dataLengthSamples, pulsewidth)
    bits = zeros(1, 8);  % Initialize a binary vector to hold the 8 bits
    startIdx = 1;  % Start index for extracting chunks

    for i = 1:8
      
        % Determine the end index dynamically
        endIdx = min(startIdx + pulsewidth - 1, length(dataLengthSamples));
         % disp(['startIdx', num2str(startIdx + 87),'end idx', num2str(endIdx +87)]);
        chunk = dataLengthSamples(startIdx:endIdx);
        disp(chunk);
        % Determine if the chunk represents 1 or 0
        if mean(chunk) > 0.5
            bits(i) = 1;
            % Find last occurrence of 1
            lastOneIdx = find(chunk == 1, 1, 'last');
            if ~isempty(lastOneIdx)
                startIdx = startIdx + lastOneIdx; % Move to where ones end
            else
                startIdx = endIdx + 1;
            end
        else
            bits(i) = 0;
            % Find last occurrence of 0
            lastZeroIdx = find(chunk == 0, 1, 'last');
            if ~isempty(lastZeroIdx)
                startIdx = startIdx + lastZeroIdx; % Move to where zeros end
            else
                startIdx = endIdx + 1;
            end
        end

        % Ensure start index does not exceed bounds
        if startIdx > length(dataLengthSamples)
            break;
        end
       
    end

    % Convert the binary vector to a binary number
    binaryNumber = bin2dec(num2str(bits));
    remainder = mod(binaryNumber, 7);
    binarylength = binaryNumber - remainder;

    % Display the result
    disp(['The 8-bit binary number: ', num2str(bits)]);
    disp(['The corresponding decimal value: ', num2str(binarylength)]);
end

function [binarylength , dataStart] = getLength(dataLengthSamples, pulsewidth)
    bits = zeros(1, 8);  % Initialize a binary vector to hold the 8 bits
    startIdx = 1;  % Start index for extracting chunks
    maxSample = pulsewidth * 2;
    chunkSize = round(0.8 * maxSample);  % Define chunk size

    % Reference samples for 1 and 0
    onesSample = ones(1, pulsewidth);
    zerosSample = zeros(1, pulsewidth);

    for i = 1:8
        % disp(['i',num2str(i)]);
        % Determine the end index dynamically
        endIdx = min(startIdx + chunkSize - 1, length(dataLengthSamples));
        % disp(['startIdx', num2str(startIdx +138),'end idx', num2str(endIdx+138)]);
        
        chunk = dataLengthSamples(startIdx:endIdx);

        % disp(chunk);
        if length(chunk) < pulsewidth
            break; % Stop if chunk is too small for matching
        end
        
        maxMatchScore = -Inf;
        bestMatchIdx = startIdx;

        % Slide the reference samples across the chunk and find the best match
        for j = 1:(length(chunk) - pulsewidth + 1)
            subChunk = chunk(j:j + pulsewidth - 1);
            
            matchOnes = sum(subChunk == onesSample);
            matchZeros = sum(subChunk == zerosSample);

            [maxMatch, matchType] = max([matchZeros, matchOnes]);

            if maxMatch > maxMatchScore
                maxMatchScore = maxMatch;
                bestMatchIdx = startIdx + j - 1; % Adjust for global indexing
                bits(i) = matchType - 1 ; % 1 if matched ones, 0 if matched zeros
                % disp(['matchType',num2str(matchType)]);
                % disp(['bits',num2str(bits)]);
            end
        end

        % Move start index to where the best match ended
        startIdx = bestMatchIdx + pulsewidth;

        % Ensure start index does not exceed bounds
        if startIdx > length(dataLengthSamples)
            break;
        end
    end
    dataStart = startIdx;

    % Convert the binary vector to a binary number
    binaryNumber = bin2dec(num2str(bits));
    remainder = mod(binaryNumber, 7);
    binarylength = binaryNumber - remainder;

    % Display the result
    disp(['The 8-bit binary number: ', num2str(bits)]);
    disp(['The corresponding decimal value: ', num2str(binarylength)]);
end

function [length]= getLengthold(next80Samples,pulsewidth)
        % Convert the next 80 samples to binary by checking chunks of 10 samples
        bits = zeros(1, 8);  % Initialize a binary vector to hold the 8 bits
        
        for i = 1:8
            % Extract the chunk of pulsewidth samples corresponding to one bit
            chunk = next80Samples((i - 1) * pulsewidth + 1 : i * pulsewidth);

            % Check if the chunk represents a 1 or 0 (if majority is 1, it's bit 1; else bit 0)
            if mean(chunk) > 0.5  % Mean of the chunk > 0.5 means it's closer to 1
                bits(i) = 1;
            else
                bits(i) = 0;
            end
        end

        % Convert the binary vector to a binary number
        binaryNumber = bin2dec(num2str(bits));
        remainder = mod(binaryNumber, 7);
    
        length = binaryNumber - remainder;
        % Display the result
        disp(['The 8-bit binary number: ', num2str(bits)]);
        disp(['The corresponding decimal value: ', num2str(length)]);
end

function [extractedBinaryArray] = extractBinaryFromSignal(binarySignal, startIdx, binaryNumber, pulsewidth)
    % Initialize an empty array to store the extracted binary values
    extractedBinary = zeros(1,binaryNumber);
    maxSample = pulsewidth * 2;  % Define max sample
    chunkSize = round(0.8 * maxSample);  % Define chunk size

    % Reference samples for 1 and 0
    onesSample = ones(1, pulsewidth);
    zerosSample = zeros(1, pulsewidth);

    for i = 1:binaryNumber
        % Determine the end index dynamically
        endIdx = min(startIdx + chunkSize - 1, length(binarySignal));
        % disp(['StartIdx: ', num2str(startIdx), ' EndIdx: ', num2str(endIdx)]);
        
        chunk = binarySignal(startIdx:endIdx);
        % disp(chunk);
        if length(chunk) < pulsewidth
            break; % Stop if chunk is too small for matching
        end
        
        maxMatchScore = -Inf;
        bestMatchIdx = startIdx;

        % Slide the reference samples across the chunk and find the best match
        for j = 1:(length(chunk) - pulsewidth + 1)
            subChunk = chunk(j:j + pulsewidth - 1);
            
            matchOnes = sum(subChunk == onesSample);
            matchZeros = sum(subChunk == zerosSample);
            
            [maxMatch, matchType] = max([matchZeros, matchOnes]);
            
            if maxMatch > maxMatchScore
                maxMatchScore = maxMatch;
                bestMatchIdx = startIdx + j - 1;
                % disp(bestMatchIdx);
                extractedBinary(i) = matchType - 1 ;
               
            end
        end
     
        % Move start index to where the best match ended
        startIdx = bestMatchIdx + pulsewidth;
        
        % Ensure start index does not exceed bounds
        if startIdx > length(binarySignal)
            break;
        end
    end
    
    % Convert the binary array to a string for easier reading
    binaryStr = num2str(extractedBinary);
    binaryStr(binaryStr == ' ') = '';  % Remove spaces
    extractedBinaryArray = binaryStr;
    
    disp(['Extracted Binary (as string): ', binaryStr]);
end

function [extractedBinaryArray] = extractBinaryFromSignalold(binarySignal, startIdx, binaryNumber, pulsewidth)

    % Initialize an empty array to store the extracted binary values
    extractedBinary = [];

    % Loop until we've extracted enough bits
    for i = 1:binaryNumber

        % Calculate current segment start and end positions
        segmentStart = startIdx;
        segmentEnd = startIdx + pulsewidth - 1;
        
        disp(['Start with: ', num2str(segmentStart), ' End with: ', num2str(segmentEnd)]);
        
        % Ensure indices are within bounds
        if segmentStart > length(binarySignal) || segmentEnd > length(binarySignal)
            fprintf('Could not retrieve the entire data\n');
            break;
        end    
         % Extract the segment
        segment = binarySignal(segmentStart:segmentEnd);
        disp(segment);
        % Check if the chunk represents a 1 or 0 based on the average value
        if mean(segment) > 0.5  
            extractedBinary = [extractedBinary, 1];  % Append 1
            % Find the last occurrence of 1
            lastOneIdx = find(segment == 1, 1, 'last');
            if ~isempty(lastOneIdx)
                startIdx = segmentStart + lastOneIdx;
            else
                startIdx = segmentEnd + 1;  % Move forward if no 1 is found
            end
        else
            extractedBinary = [extractedBinary, 0];  % Append 0
            % Find the last occurrence of 0
            lastZeroIdx = find(segment == 0, 1, 'last');
            if ~isempty(lastZeroIdx)
                startIdx = segmentStart + lastZeroIdx;
            else
                startIdx = segmentEnd + 1;  % Move forward if no 0 is found
            end
        end
    end
    
    % Convert the binary array to a string for easier reading
    binaryStr = num2str(extractedBinary);
    binaryStr(binaryStr == ' ') = '';  % Remove spaces
    extractedBinaryArray = binaryStr;

    disp(['Extracted Binary (as string): ', binaryStr]);

end

%expects a binary string
function [decodedText,decodedBits] = hamming74_decode(encodedBinary)
    % Function to decode Hamming (7,4) encoded binary string back to ASCII
        %disp(['encodedBinary ',encodedBinary]);
    if mod(length(encodedBinary), 7) ~= 0
        error('Encoded binary string length must be a multiple of 7');
    end
    
   
    decodedBits = [];
   
    numCodewords = length(encodedBinary) / 7;
    %disp(['Databinary ',encodedBinary]);
    % Process each 7-bit Hamming codeword
    for i = 1:numCodewords
        % Extract a 7-bit segment
        codeword = encodedBinary((i-1)*7 + 1 : i*7) - '0';
        
        % Correct the error if present
        correctedData = correctHamming74(codeword);
        
        % Append the 4-bit decoded data
        decodedBits = [decodedBits, correctedData];
    end

    % Convert decoded bits to ASCII characters
    decodedText = binaryToAscii(decodedBits);
    
   
end

function correctedData = correctHamming74(codeword)
    % Error correction for Hamming (7,4)
    
    % Hamming (7,4) parity-check matrix
    H = [1 0 1 0 1 0 1; 
         0 1 1 0 0 1 1; 
         0 0 0 1 1 1 1];
    %disp(H')
    %   disp('code')
    %  disp(codeword)
   
    % Compute syndrome using matrix multiplication (codeword * H^T)
    syndrome = mod(codeword * H', 2);  % Corrected calculation

    % Convert syndrome to decimal index (1-based)
    errorIndex = binaryToDecimal(flip(syndrome));  % No 'left-msb' needed
    
    % Correct the error if detected
    if errorIndex > 0
        fprintf('Error detected at position %d. Correcting...\n', errorIndex);
        codeword(errorIndex) = mod(codeword(errorIndex) + 1, 2); % Flip the bit
    end
    % disp('correctedData')
    % disp(codeword)
    % Extract the original 4-bit data from corrected codeword
    correctedData = [codeword(3), codeword(5), codeword(6), codeword(7)];
end

function decimalValue = binaryToDecimal(binaryArray)
    % Converts a binary array (e.g., [1 0 1 1]) to a decimal number
    decimalValue = sum(binaryArray .* 2.^(length(binaryArray)-1:-1:0));
end

function asciiText = binaryToAscii(binaryData)
    % Convert binary array to ASCII text
    asciiText = '';
    numChars = floor(length(binaryData) / 8);
    
    for i = 1:numChars
        byte = binaryData((i-1)*8 + 1 : i*8);
        asciiValue = binaryToDecimal(byte); % Using custom function instead of bi2de
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