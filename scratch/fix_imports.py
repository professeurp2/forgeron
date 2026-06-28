import os
import glob

dart_files = glob.glob('lib/**/*.dart', recursive=True)

for file in dart_files:
    with open(file, 'r', encoding='utf-8') as f:
        content = f.read()

    parts = file.replace('\\', '/').split('/')
    depth = len(parts) - 1
    
    prefix = '../' * (depth - 1)
    if depth == 1:
        prefix = './'
        
    di_import = f"import '{prefix}application/providers/di_providers.dart';"
    ui_import = f"import '{prefix}application/providers/ui_state_provider.dart';"
    
    changed = False
    
    if 'machineRepositoryProvider' in content and 'di_providers.dart' not in content:
        last_import_idx = content.rfind('import ')
        if last_import_idx != -1:
            end_of_line = content.find('\n', last_import_idx)
            content = content[:end_of_line+1] + di_import + '\n' + content[end_of_line+1:]
            changed = True
            
    if 'showVectorsProvider' in content and 'ui_state_provider.dart' not in content:
        last_import_idx = content.rfind('import ')
        if last_import_idx != -1:
            end_of_line = content.find('\n', last_import_idx)
            content = content[:end_of_line+1] + ui_import + '\n' + content[end_of_line+1:]
            changed = True
    
    if changed:
        with open(file, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Fixed imports in {file}")
