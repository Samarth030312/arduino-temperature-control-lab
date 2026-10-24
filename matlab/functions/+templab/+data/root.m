function r = root()
%ROOT  Where run data lives: the repository, or TEMPLAB_DATA_ROOT (tests write elsewhere).
    r = templab.repoRoot();
    if ~isempty(getenv('TEMPLAB_DATA_ROOT')), r = getenv('TEMPLAB_DATA_ROOT'); end
end
