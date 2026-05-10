import os
import json
import re
import argparse

def clean_filename(filename):
    # Remove invalid characters and replace with underscores
    return re.sub(r'[<>:"/\\|?*]', '_', filename)

def get_loras_from_json(json_data):
    loras = set()  # Using a set to avoid duplicates
    
    def search_loras(data):
        if isinstance(data, dict):
            # Check if this is a LoraLoader node
            if data.get('type') == 'LoraLoader':
                # Get LORA name from widgets_values
                widgets_values = data.get('widgets_values', [])
                if widgets_values and isinstance(widgets_values[0], str):
                    lora_name = widgets_values[0]
                    if lora_name.endswith('.safetensors'):
                        loras.add(lora_name.replace('.safetensors', ''))
                    else:
                        loras.add(lora_name)
                
            # Search in nested structures
            for value in data.values():
                search_loras(value)
        elif isinstance(data, list):
            # Search in all list items
            for item in data:
                search_loras(item)
    
    try:
        search_loras(json_data)
    except Exception as e:
        print(f"Error while searching for LORAs: {e}")
    
    return sorted(list(loras))  # Convert set back to sorted list

def process_folder(folder_path):
    print(f"Processing files in: {folder_path}")
    
    # Files to ignore
    ignore_files = [
        'video_wan2_2_5b_i2v',
        'depth_controlnet',
        'flux_redux_model_example',
        'image_qwen_image_union_control_lora',
        'image2image'
    ]
    
    # Process each JSON file in the directory
    for filename in os.listdir(folder_path):
        if not filename.endswith('.json'):
            continue
            
        # Skip files that match the ignore list
        base_name = os.path.splitext(filename)[0]
        if any(ignore in base_name.lower() for ignore in ignore_files):
            print(f"Skipping ignored file: {filename}")
            continue

        file_path = os.path.join(folder_path, filename)
        print(f"\nProcessing file: {filename}")
        
        try:
            # Read and parse the JSON file
            with open(file_path, 'r', encoding='utf-8') as f:
                try:
                    json_data = json.load(f)
                    print(f"Successfully loaded JSON from {filename}")
                except json.JSONDecodeError as e:
                    print(f"Error parsing JSON in {filename}: {e}")
                    continue

            # Extract LORA names
            loras = get_loras_from_json(json_data)
            
            if not loras:
                print(f"No LORAs found in {filename}, skipping...")
                continue

            print(f"Found LORAs in {filename}: {', '.join(loras)}")

            # Create new filename
            new_name = ','.join(loras)
            if len(new_name) > 200:  # Limit filename length
                new_name = new_name[:197] + '...'
            
            new_name = clean_filename(new_name) + '.json'
            new_path = os.path.join(folder_path, new_name)

            # Check if the new filename already exists
            counter = 1
            base_new_name = new_name[:-5]  # Remove .json
            while os.path.exists(new_path) and new_path != file_path:
                new_name = f"{base_new_name}_{counter}.json"
                new_path = os.path.join(folder_path, new_name)
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

def main():
    parser = argparse.ArgumentParser(description='Rename workflow JSON files based on contained LORAs')
    parser.add_argument('--folder', '-f', help='Folder path containing workflow JSON files', 
                       default=os.path.dirname(os.path.abspath(__file__)))
    
    args = parser.parse_args()
    process_folder(args.folder)

if __name__ == "__main__":
    main()