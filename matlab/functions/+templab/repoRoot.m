function r = repoRoot()
%REPOROOT  Absolute path of the arduino-temperature-control-lab repository.
    r = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
end
