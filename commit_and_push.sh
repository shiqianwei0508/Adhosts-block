set -e
cd /home/work/source/Adhosts-block/

#!/bin/bash

max_attempts=10
attempt=1

while [ $attempt -le $max_attempts ]
do
    echo "Attempt $attempt:"
    /usr/bin/git pull

    if [ $? -eq 0 ]; then
        echo "Git pull successful"
        break
    else
        echo "Git pull failed"
        attempt=$((attempt + 1))
    fi

    if [ $attempt -gt $max_attempts ]; then
        echo "Maximum attempts reached. Exiting..."
        break
    fi

    sleep 1
done


#/usr/bin/git pull
/usr/bin/bash update_action.sh
/usr/bin/git add .
/usr/bin/git commit -m update
/usr/bin/git push
