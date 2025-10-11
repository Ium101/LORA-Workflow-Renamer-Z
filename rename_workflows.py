import os
import json
import re

def clean_filename(filename):
    # Remove invalid characters and replace with underscores
    return re.sub(r'[<>:"/\\|?*]', '_', filename)

def get_loras_from_json(json_data):
    loras = set()  # Using a set to avoid duplicates
    
    # Files to ignore
    ignore_files = [
        'video_wan2_2_5B_i2v',
        'depth_controlnet',
        'flux_redux_model_example',
        'image_qwen_image_union_control_lora',
        'image2image'
    ]
    
    # Function to recursively search for LORA nodes
    def search_loras(data):
        if isinstance(data, dict):
            # Check if this is a LORA node
            if data.get('class_type') == 'LoraLoader':
                lora_name = data.get('inputs', {}).get('lora_name', '')
                if lora_name and isinstance(lora_name, str):
                    loras.add(lora_name)
            
            # Search in all dictionary values
            for value in data.values():
                search_loras(value)
        elif isinstance(data, list):
            # Search in all list items
            for item in data:
                search_loras(item)
    
    search_loras(json_data)
    return sorted(list(loras))  # Convert set back to sorted list

def main():
    workflow_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Process each JSON file in the directory
    for filename in os.listdir(workflow_dir):
        if not filename.endswith('.json'):
            continue
            
        # Skip files that match the ignore list
        base_name = os.path.splitext(filename)[0]
        if any(ignore in base_name.lower() for ignore in [
            'video_wan2_2_5b_i2v',
            'depth_controlnet',
            'flux_redux_model_example',
            'image_qwen_image_union_control_lora',
            'image2image'
        ]):
            print(f"Skipping ignored file: {filename}")
            continue

        file_path = os.path.join(workflow_dir, filename)
        
        try:
            # Read and parse the JSON file
            with open(file_path, 'r', encoding='utf-8') as f:
                try:
                    json_data = json.load(f)
                except json.JSONDecodeError as e:
                    print(f"Error parsing JSON in {filename}: {e}")
                    continue

            # Extract LORA names
            loras = get_loras_from_json(json_data)
            
            if not loras:
                print(f"No LORAs found in {filename}, skipping...")
                continue

            # Create new filename
            new_name = ','.join(loras)
            if len(new_name) > 200:  # Limit filename length
                new_name = new_name[:197] + '...'
            
            new_name = clean_filename(new_name) + '.json'
            new_path = os.path.join(workflow_dir, new_name)

            # Check if the new filename already exists
            counter = 1
            base_new_name = new_name[:-5]  # Remove .json
            while os.path.exists(new_path) and new_path != file_path:
                new_name = f"{base_new_name}_{counter}.json"
                new_path = os.path.join(workflow_dir, new_name)
                counter += 1

            # Rename the file if the name would change
            if new_path != file_path:
                try:
                    os.rename(file_path, new_path)
                    print(f"Renamed: {filename} -> {new_name}")
                except OSError as e:
                    print(f"Error renaming {filename}: {e}")
            else:
                print(f"File {filename} already has the correct name")

        except Exception as e:
            print(f"Unexpected error processing {filename}: {e}")

if __name__ == "__main__":
    main()