while [ 1 ]; do
    clear
    dothistroma ~/Dropbox/org/project.org
    inotifywait -r -e modify /home/nushio/Dropbox/org/ -t 60
done
