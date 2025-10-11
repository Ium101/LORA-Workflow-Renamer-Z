import os
import json
import re
import tkinter as tk
from tkinter import ttk
from tkinter import filedialog, messagebox
import threading

class WorkflowRenamerGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("LORA Workflow Renamer")
        self.root.geometry("800x600")
        
        # Create main frame
        self.main_frame = ttk.Frame(root, padding="10")
        self.main_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # Folder selection and buttons in one row
        self.folder_frame = ttk.Frame(self.main_frame)
        self.folder_frame.grid(row=0, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=5)
        
        self.folder_path = tk.StringVar(value=os.path.dirname(os.path.abspath(__file__)))
        self.folder_entry = ttk.Entry(self.folder_frame, textvariable=self.folder_path, width=60)
        self.folder_entry.grid(row=0, column=0, padx=5)
        
        self.button_frame = ttk.Frame(self.folder_frame)
        self.button_frame.grid(row=0, column=1, padx=5)
        
        self.browse_button = ttk.Button(self.button_frame, text="Browse", command=self.browse_folder)
        self.browse_button.pack(side=tk.LEFT, padx=2)
        
        # Process button next to Browse button
        self.process_button = ttk.Button(self.button_frame, text="Process Files", command=self.start_processing)
        self.process_button.pack(side=tk.LEFT, padx=2)
        
        # Progress bar
        self.progress_var = tk.DoubleVar()
        self.progress_bar = ttk.Progressbar(self.main_frame, variable=self.progress_var, maximum=100)
        self.progress_bar.grid(row=1, column=0, columnspan=2, sticky=(tk.W, tk.E), pady=5)
        
        # Output text
        self.output_frame = ttk.Frame(self.main_frame)
        self.output_frame.grid(row=2, column=0, columnspan=2, sticky=(tk.W, tk.E, tk.N, tk.S), pady=5)
        
        self.output_text = tk.Text(self.output_frame, height=20, width=80, wrap=tk.WORD)
        self.output_text.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        
        self.scrollbar = ttk.Scrollbar(self.output_frame, orient=tk.VERTICAL, command=self.output_text.yview)
        self.scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        self.output_text['yscrollcommand'] = self.scrollbar.set
        
        # Configure grid weights
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(0, weight=1)
        self.main_frame.columnconfigure(1, weight=1)
        self.main_frame.rowconfigure(3, weight=1)
        
        # Processing flag
        self.is_processing = False

    def browse_folder(self):
        folder = filedialog.askdirectory()
        if folder:
            self.folder_path.set(folder)

    def update_output(self, text):
        self.output_text.insert(tk.END, text + '\n')
        self.output_text.see(tk.END)
        self.root.update_idletasks()

    def clean_filename(self, filename):
        return re.sub(r'[<>:"/\\|?*]', '_', filename)

    def get_loras_from_json(self, json_data):
        loras = set()
        
        def search_loras(data):
            if isinstance(data, dict):
                if data.get('type') == 'LoraLoader':
                    widgets_values = data.get('widgets_values', [])
                    if widgets_values and isinstance(widgets_values[0], str):
                        lora_name = widgets_values[0]
                        if lora_name.endswith('.safetensors'):
                            loras.add(lora_name.replace('.safetensors', ''))
                        else:
                            loras.add(lora_name)
                    
                for value in data.values():
                    search_loras(value)
            elif isinstance(data, list):
                for item in data:
                    search_loras(item)
        
        try:
            search_loras(json_data)
        except Exception as e:
            self.update_output(f"Error while searching for LORAs: {e}")
        
        return sorted(list(loras))

    def process_files(self):
        folder_path = self.folder_path.get()
        
        if not os.path.exists(folder_path):
            messagebox.showerror("Error", "Selected folder does not exist!")
            return
        
        self.update_output(f"Processing files in: {folder_path}")
        
        # Files to ignore
        ignore_files = [
            'video_wan2_2_5b_i2v',
            'depth_controlnet',
            'flux_redux_model_example',
            'image_qwen_image_union_control_lora',
            'image2image'
        ]
        
        # Get list of JSON files
        json_files = [f for f in os.listdir(folder_path) if f.endswith('.json')]
        total_files = len(json_files)
        processed_files = 0
        
        for filename in json_files:
            if not self.is_processing:
                break
                
            base_name = os.path.splitext(filename)[0]
            if any(ignore in base_name.lower() for ignore in ignore_files):
                self.update_output(f"Skipping ignored file: {filename}")
                processed_files += 1
                self.progress_var.set((processed_files / total_files) * 100)
                continue

            file_path = os.path.join(folder_path, filename)
            self.update_output(f"\nProcessing file: {filename}")
            
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    try:
                        json_data = json.load(f)
                        self.update_output(f"Successfully loaded JSON from {filename}")
                    except json.JSONDecodeError as e:
                        self.update_output(f"Error parsing JSON in {filename}: {e}")
                        continue

                loras = self.get_loras_from_json(json_data)
                
                if not loras:
                    self.update_output(f"No LORAs found in {filename}, skipping...")
                    processed_files += 1
                    self.progress_var.set((processed_files / total_files) * 100)
                    continue

                self.update_output(f"Found LORAs in {filename}: {', '.join(loras)}")

                new_name = ','.join(loras)
                if len(new_name) > 200:
                    new_name = new_name[:197] + '...'
                
                new_name = self.clean_filename(new_name) + '.json'
                new_path = os.path.join(folder_path, new_name)

                counter = 1
                base_new_name = new_name[:-5]
                while os.path.exists(new_path) and new_path != file_path:
                    new_name = f"{base_new_name}_{counter}.json"
                    new_path = os.path.join(folder_path, new_name)
                    counter += 1

                if new_path != file_path:
                    try:
                        os.rename(file_path, new_path)
                        self.update_output(f"Renamed: {filename} -> {new_name}")
                    except OSError as e:
                        self.update_output(f"Error renaming {filename}: {e}")
                else:
                    self.update_output(f"File {filename} already has the correct name")

            except Exception as e:
                self.update_output(f"Unexpected error processing {filename}: {e}")
            
            processed_files += 1
            self.progress_var.set((processed_files / total_files) * 100)
        
        if self.is_processing:
            self.update_output("\nProcessing completed!")
        else:
            self.update_output("\nProcessing cancelled!")
        
        self.is_processing = False
        self.process_button.configure(text="Process Files")

    def start_processing(self):
        if not self.is_processing:
            self.is_processing = True
            self.process_button.configure(text="Cancel")
            self.output_text.delete(1.0, tk.END)
            self.progress_var.set(0)
            threading.Thread(target=self.process_files, daemon=True).start()
        else:
            self.is_processing = False
            self.process_button.configure(text="Process Files")

def main():
    root = tk.Tk()
    app = WorkflowRenamerGUI(root)
    root.mainloop()

if __name__ == "__main__":
    main()