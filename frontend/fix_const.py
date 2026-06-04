import os
import re

lib_dir = '/Users/methas/Desktop/Paycif/frontend/lib'

count = 0
for root, dirs, files in os.walk(lib_dir):
    for f in files:
        if f.endswith('.dart'):
            filepath = os.path.join(root, f)
            with open(filepath, 'r') as file:
                content = file.read()
            
            new_content = re.sub(r'const\s+AppTheme\.', 'AppTheme.', content)
            
            if new_content != content:
                with open(filepath, 'w') as file:
                    file.write(new_content)
                count += 1
                print(f"Updated {filepath}")
print(f"Total files updated: {count}")
