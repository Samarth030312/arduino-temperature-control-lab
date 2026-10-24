function A = apparatus(code)
%APPARATUS  The rig of this repository: run-id code, data folder, telemetry type, firmware.
%
%   A = templab.data.apparatus()           % or apparatus('TEMP')
    all = struct('code', 'TEMP', 'folder', 'temperature', 'tel', 'TTEL', 'sketch', 'temperature', ...
        'name', 'Temperature (bulb, DHT11, SSR)');
    if nargin == 0, A = all; return; end
    A = all(strcmpi({all.code}, code));
    assert(~isempty(A), 'templab:data:apparatus', 'unknown apparatus %s (this repository: TEMP)', code);
end
