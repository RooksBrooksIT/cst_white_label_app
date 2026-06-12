import os
import re

def refactor():
    lib_dir = "lib"
    
    # regex for FirebaseFirestore.instance.collection("xxx")
    pattern_direct = re.compile(r'FirebaseFirestore\.instance\.collection\(\s*([\'"][^\'"]+[\'"])\s*\)', re.DOTALL)
    # regex for _firestore.collection("xxx")
    pattern_fs = re.compile(r'_firestore\.collection\(\s*([\'"][^\'"]+[\'"])\s*\)', re.DOTALL)
    
    ignore_list = ["'organizationUser'", '"organizationUser"', "'referralCodes'", '"referralCodes"']
    
    modified_files = 0
    for root, _, files in os.walk(lib_dir):
        for file in files:
            if not file.endswith('.dart'):
                continue
                
            path = os.path.join(root, file)
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read()
                
            orig_content = content
            
            def replace_match(match):
                col_name = match.group(1)
                if col_name in ignore_list:
                    return match.group(0) # don't change
                return f'FirestoreService.getCollection({col_name})'
            
            content = pattern_direct.sub(replace_match, content)
            content = pattern_fs.sub(replace_match, content)
            
            if content != orig_content:
                # Add import if missing
                if 'import \'package:demo_cst/services/firestore_service.dart\';' not in content and 'import \'../services/firestore_service.dart\';' not in content:
                    lines = content.split('\n')
                    import_idx = 0
                    for i, line in enumerate(lines):
                        if line.startswith('import '):
                            import_idx = i
                    lines.insert(import_idx + 1, "import 'package:demo_cst/services/firestore_service.dart';")  # type: ignore
                    content = '\n'.join(lines)
                    
                with open(path, 'w', encoding='utf-8') as f:
                    f.write(content)
                    
                modified_files += 1

    print(f"Refactored {modified_files} files.")

if __name__ == "__main__":
    refactor()
