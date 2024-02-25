%% READ FILE AND CONVERT IT TO NUM MATRIX
measurementsFileName = 'mjerenja1.txt';

fileID = fopen(measurementsFileName, 'r');
if fileID == -1
    error('Failed to open file.');
end

measurementMatrix = [];

while ~feof(fileID)
    line = fgetl(fileID); 
    numbers = str2num(line); 
    measurementMatrix = [measurementMatrix; numbers]; 
end
fclose(fileID);

[numRows, numCols] = size(measurementMatrix);

colorLimits = [0.5 5];
imagesc(abs(measurementMatrix), colorLimits);

%% DO HILBERT TRANSFORM
hilbertTransformedData = hilbert(measurementMatrix);

%% PREREQUISETS

carrierFrequency = 24e9;
bandwidth = 1300e6;
elementSpacing = 5e-3;
referenceRange = 35e-2;
speedOfLight = 3e8;
%% DO ZERO PADDING

totalPadding = 1024; 
padSize = totalPadding / 2; 
paddedData = padarray(hilbertTransformedData, [padSize, 0], 'both');
numRows = size(paddedData, 1);

%% DO AZIMUTH FFT
fftDataAzimuth = fft(paddedData, numRows, 1);
fftDataAzimuthShifted = fftshift(fftDataAzimuth, 1);

imagesc(abs(fftDataAzimuthShifted));
title("Azimuth FFT"); %kx kr

%% DO RFM 
kx = linspace(-pi/elementSpacing, pi/elementSpacing, numRows);
kr = linspace(4*pi*carrierFrequency/speedOfLight-4*pi*bandwidth/speedOfLight, 4*pi*carrierFrequency/speedOfLight+4*pi*bandwidth/speedOfLight, numCols);

for kxIndex = 1:numRows
    for krIndex = 1:numCols
        rfmData(kxIndex, krIndex) = fftDataAzimuthShifted(kxIndex, krIndex) * exp(-1i * (-referenceRange*kr(krIndex) + referenceRange*sqrt(kr(krIndex)^2 - kx(kxIndex)^2)));
    end
end

figure;
imagesc(abs(fftshift(ifft(rfmData, numCols, 2), 2)));
title("kx - r");

figure;
imagesc(abs(fftshift(ifft2(rfmData), 2)));
title("x - r");

%% DO STOLT INTERPOLATION
ky = sqrt((kr.^2 - (kx').^2).*(kr.^2 - (kx').^2 > 0));

for rowIndex = 1:size(rfmData,1)
    stoltInterpolatedData(rowIndex,:) = interp1(ky(rowIndex,:), rfmData(rowIndex,:), kr, 'linear', 1e-30);
end

figure;
imagesc(abs(stoltInterpolatedData));
title("kx - kr");

%% DO RECONSTRUCTION
finalImage = ifft2(stoltInterpolatedData);
finalImageShifted = fftshift(finalImage, 2);

figure;
imagesc(abs(finalImageShifted));
title("X - R, final image");
