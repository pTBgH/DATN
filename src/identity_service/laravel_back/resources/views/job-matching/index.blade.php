<!-- resources/views/job-matching/index.blade.php -->
@extends('layouts.app')

@section('content')
<div class='upload-form'>
    {{-- Keyword Search Form (Remains separate) --}}
    <form id="filtersForm" method="POST" action="{{ route('fastjob.search') }}">
        @csrf
        <p style="color: gray; font-size: 0.9rem;">Try out our new full-text and keyword search!</p>

        <div id="keywordBox" style="display: flex; flex-wrap: wrap; border: 1px solid #ccc; padding: 6px; border-radius: 4px; min-height: 40px;">
            <input
                type="text"
                id="keywordInput"
                placeholder="Type keywords and hit double space..."
                style="border: none; outline: none; flex: 1;"
                autocomplete="off"
            >
        </div>

        <input type="hidden" name="keywords" id="keywordsHiddenInput">

        <button type="submit" id="keywordSearchButton" class="keyword-button" style="margin-top: 10px;" disabled>Search</button>
    </form>
</div>

<div style="margin-top: 30px;"></div>

<div class="upload-form">
    {{-- CV Upload Form with Integrated Filters --}}
    <h2>Create your user profile & Find Matching Jobs!</h2>
    <form id="uploadForm" action="{{ route('upload.cv') }}" method="post" enctype="multipart/form-data">
        @csrf
        <div class="upload-section">
            <h3>1. Upload CV</h3>
            <div class="upload-box" id="cvUploadBox">
                <div class="upload-info">
                    <div class="upload-icon">⬆️</div>
                    <div class="upload-text">
                        <strong>Drag and drop file here</strong>
                        <span>Limit 20MB per file • PDF</span>
                    </div>
                </div>
                <button type="button" class="browse-button" onclick="document.getElementById('cvInput').click()">Browse files</button>
            </div>
            <input type="file" id="cvInput" name="cv" accept=".pdf" style="display: none;" onchange="handleFileSelect(this, 'cvUploadBox', 'cvFileInfo')">
            <div id="cvFileInfo" class="file-info hidden"></div>
        </div>

        {{-- NEW INTEGRATED FILTER SECTION --}}
        <div class="filter-section">
            <h3>2. Add Filters (Optional)</h3>
            <div class="form-group">
                <label for="province">Province</label>
                <select id="province" name="province" class="form-control">
                    <option value="">Select a province</option>
                    {{-- Options will be populated by JavaScript --}}
                </select>
            </div>

            <div class="form-group">
                <label for="district">District</label>
                <select id="district" name="district" class="form-control" disabled> {{-- Start disabled --}}
                    <option value="">Select a district</option>
                    {{-- Options will be populated by JavaScript --}}
                </select>
            </div>

            <div class="form-group">
                <label for="filter_salary_mode">Salary Filter Mode</label>
                <select id="filter_salary_mode" name="filter_salary_mode" class="form-control">
                    <option value="">None</option>
                    <option value="max">Maximum of</option>
                    <option value="min">Minimum of</option>
                </select>
            </div>

            <div class="form-group" id="salary-container" style="display: none;"> {{-- Initially hidden --}}
                <label for="salary">Salary Threshold</label>
                <input type="number" id="salary" name="salary" placeholder="Enter salary threshold" class="form-control">
            </div>
        </div>
        {{-- END NEW INTEGRATED FILTER SECTION --}}

        <button type="submit" id="cvSubmitButton" class="submit-button" disabled>Upload CV & Get Recommendations</button>
        <p style="color: gray; font-size: 14px; margin-top: 5px; text-align: center;">
            While we accept scanned PDFs as your CV, we strongly recommend that you upload your CV in a text-based form for the optimal matching result!
        </p>
    </form>
</div>
@endsection

@section('styles')
<style>
    body {
        font-family: 'Nunito', sans-serif;
        max-width: 800px;
        margin: 50px auto;
        padding: 20px;
    }
    h1 {
        display: flex;
        align-items: center;
        gap: 10px;
    }
    h1::before {
        content: "🔗";
        font-size: 24px;
    }
    .upload-form {
        max-width: 800px;
        margin: auto;
        padding: 20px;
        border: 1px solid #ccc;
        border-radius: 10px;
        box-shadow: 0 0 10px rgba(0, 0, 0, 0.1);
    }
    .upload-form h2 {
        margin-bottom: 20px;
        text-align: center;
    }
    .upload-section {
        margin-bottom: 20px;
    }
    .upload-box {
        display: flex;
        align-items: center;
        justify-content: space-between;
        background-color: #f8f8ff;
        border-radius: 8px;
        padding: 15px 20px;
        margin: 20px auto 0; /* Adjusted margin */
    }
    .upload-info {
        display: flex;
        align-items: center;
        gap: 15px;
    }
    .upload-icon {
        color: #a0a0a0;
        font-size: 24px;
    }
    .upload-text {
        display: flex;
        flex-direction: column;
    }
    .upload-text strong {
        color: #606060;
        font-size: 16px;
        font-weight: normal;
    }
    .upload-text span {
        color: #a0a0a0;
        font-size: 14px;
    }
    .browse-button {
        background-color: #ffffff;
        border: 1px solid #d1d5db;
        color: #374151;
        padding: 8px 12px;
        border-radius: 6px;
        font-size: 14px;
        cursor: pointer;
        transition: background-color 0.3s;
    }
    .browse-button:hover {
        background-color: #f9fafb;
    }
    .file-info {
        display: flex;
        align-items: center;
        gap: 10px;
        margin-top: 10px;
        background-color: #f0f0f0;
        padding: 5px;
        border-radius: 5px;
    }
    .file-icon {
        font-size: 20px;
    }
    .success-message {
        color: green;
        margin-top: 20px;
    }
    .hidden {
        display: none;
    }

    /* Generic styles for both buttons */
    .submit-button, .keyword-button {
        color: white;
        padding: 12px 20px;
        border: none;
        border-radius: 4px;
        cursor: pointer;
        font-size: 16px;
        transition: background-color 0.3s ease, border-color 0.3s ease, color 0.3s ease;
        display: block;
        margin: 20px auto;
        width: auto; /* Adjust width or make it full width */
        min-width: 200px;
        background-color: #4CAF50; /* Enabled color */
    }
    #cvSubmitButton { /* Specific for the main submit button */
        width: 300px; /* Example width */
    }


    .submit-button:hover:not(:disabled),
    .keyword-button:hover:not(:disabled) {
        background-color: #45a049;
    }

    .submit-button:focus:not(:disabled),
    .keyword-button:focus:not(:disabled) {
        outline: none;
        box-shadow: 0 0 0 3px rgba(76, 175, 80, 0.5);
    }

    .submit-button:active:not(:disabled),
    .keyword-button:active:not(:disabled) {
        transform: translateY(1px);
    }

    .submit-button:disabled,
    .keyword-button:disabled {
        background-color: #d1d5db;
        color: #9ca3af;
        cursor: not-allowed;
        border: 1px solid #d1d5db;
    }

    /* Styles for the new filter section */
    .filter-section {
        margin-top: 30px;
        margin-bottom: 20px;
        padding: 20px;
        border: 1px solid #e0e0e0;
        border-radius: 8px;
        background-color: #f9f9f9;
    }
    .filter-section h3 {
        margin-top: 0;
        margin-bottom: 15px;
        font-size: 1.2em; /* Slightly larger */
        color: #333;
        text-align: left; /* Align with form fields */
    }
    .form-group {
        margin-bottom: 15px;
    }
    .form-group label {
        display: block;
        margin-bottom: 8px; /* Increased spacing */
        font-weight: 600; /* Slightly bolder */
        color: #4a5568; /* Tailwind gray-700 */
    }
    .form-control {
        width: 100%;
        padding: 10px 12px; /* Adjusted padding */
        border: 1px solid #cbd5e0; /* Tailwind gray-400 */
        border-radius: 6px; /* Slightly more rounded */
        box-sizing: border-box;
        font-size: 1rem;
        background-color: #fff;
        transition: border-color 0.2s ease-in-out, box-shadow 0.2s ease-in-out;
    }
    .form-control:focus {
        border-color: #4CAF50; /* Highlight color */
        box-shadow: 0 0 0 2px rgba(76, 175, 80, 0.3);
        outline: none;
    }
    select.form-control:disabled {
        background-color: #e2e8f0; /* Tailwind gray-300 */
        opacity: 0.7;
        cursor: not-allowed;
    }
    input[type="number"].form-control {
        /* Add specific styles if number input needs to behave differently */
    }

</style>
@endsection


@section('scripts')
<script>
    // --- Debugging Helper ---
    function logState(message, cvButtonDisabled, keywordButtonDisabled) {
        // console.log(`[DEBUG] ${message} | CV Button Disabled: ${cvButtonDisabled} | Keyword Button Disabled: ${keywordButtonDisabled ?? 'N/A'}`);
    }

    document.addEventListener('DOMContentLoaded', function () {
        // --- Get Element References ---
        const cvInput = document.getElementById('cvInput');
        const cvSubmitButton = document.getElementById('cvSubmitButton');
        const cvUploadBox = document.getElementById('cvUploadBox');
        const cvFileInfoDiv = document.getElementById('cvFileInfo');

        const keywordInputElement = document.getElementById("keywordInput"); // Renamed to avoid conflict
        const keywordBox = document.getElementById("keywordBox");
        const keywordsHiddenInput = document.getElementById("keywordsHiddenInput");
        const keywordSearchButton = document.getElementById('keywordSearchButton');

        // --- New Filter Element References ---
        const provinceSelect = document.getElementById('province');
        const districtSelect = document.getElementById('district');
        const salaryModeSelect = document.getElementById('filter_salary_mode');
        const salaryContainer = document.getElementById('salary-container');
        const salaryInput = document.getElementById('salary');

        let keywords = [];

        // --- Initial State Logging ---
        logState('DOMContentLoaded - Initial State', cvSubmitButton.disabled, keywordSearchButton?.disabled);

        // --- CV Upload Logic ---
        if (cvInput && cvSubmitButton) {
            cvInput.addEventListener('change', function () {
                const file = cvInput.files[0];
                let shouldEnableCvButton = false;

                if (file) {
                    if (file.type !== 'application/pdf') {
                        alert('CV must be a PDF file.');
                        cvInput.value = ''; // Reset file input
                        clearCvDisplay();
                    } else if (file.size > 20 * 1024 * 1024) { // 20MB limit
                        alert('The file exceeds the 20MB limit.');
                        cvInput.value = ''; // Reset file input
                        clearCvDisplay();
                    } else {
                        shouldEnableCvButton = true;
                        displayFileInfo(file, 'cvFileInfo');
                        if (cvUploadBox) { // Ensure cvUploadBox exists
                           const browseButton = cvUploadBox.querySelector('.browse-button');
                           if (browseButton) browseButton.style.display = 'none';
                        }
                    }
                } else {
                    clearCvDisplay();
                }
                cvSubmitButton.disabled = !shouldEnableCvButton;
                logState('After cvInput change', cvSubmitButton.disabled, keywordSearchButton?.disabled);
            });
        } else {
             console.error('[DEBUG] CV Input or CV Submit Button not found!');
        }

        // --- Keyword Search Logic ---
        if (keywordInputElement && keywordSearchButton) {
            keywordInputElement.addEventListener("input", function(e) {
                let keywordValueChanged = false;
                if (keywordInputElement.value.endsWith("  ")) {
                    const value = keywordInputElement.value.slice(0, -2).trim();
                    if (value && !keywords.includes(value)) {
                        keywords.push(value);
                        keywordValueChanged = true;
                    }
                    keywordInputElement.value = "";
                }
                if (keywordValueChanged) {
                    renderKeywords();
                    keywordInputElement.focus();
                }
            });
            keywordInputElement.addEventListener("keydown", function(e) {
                if (e.key === "Backspace" && keywordInputElement.value === "" && keywords.length > 0) {
                    e.preventDefault();
                    const lastKeyword = keywords.pop();
                    keywordInputElement.value = lastKeyword;
                    renderKeywords();
                }
            });
        } else {
            // console.warn('[DEBUG] Keyword Input or Keyword Search Button not found (this is fine if form is not present).');
        }

        // --- New Filter Logic ---
        if (provinceSelect && districtSelect && salaryModeSelect && salaryContainer && salaryInput) {
            // Fetch Provinces
            fetch('/api/provinces') // Ensure this route exists and returns JSON: [{code: "ID", name: "Province Name"}, ...]
                .then(response => {
                    if (!response.ok) throw new Error(`HTTP error! status: ${response.status}, URL: ${response.url}`);
                    return response.json();
                })
                .then(data => {
                    if (!Array.isArray(data)) throw new Error('Provinces API did not return an array.');
                    data.forEach(province => {
                        const option = document.createElement('option');
                        option.value = province.code; // Assuming 'code' is the value like '01', 'AB', etc.
                        option.textContent = province.name; // Assuming 'name' is the display text like "Jakarta", "Alberta"
                        provinceSelect.appendChild(option);
                    });
                })
                .catch(error => {
                    console.error('Error fetching provinces:', error);
                    // Optionally, disable province select or show an error message
                });

            // Province change listener
            provinceSelect.addEventListener('change', function() {
                const provinceCode = this.value;
                districtSelect.innerHTML = '<option value="">Select a district</option>'; // Reset districts
                districtSelect.disabled = true;
                // salaryInput.value = ''; // Optional: Reset salary if province changes

                if (provinceCode) {
                    fetch(`/api/districts/${provinceCode}`) // Ensure this route exists, e.g., /api/districts/01
                        .then(response => {
                            if (!response.ok) throw new Error(`HTTP error! status: ${response.status}, URL: ${response.url}`);
                            return response.json();
                        })
                        .then(data => {
                             if (!Array.isArray(data)) throw new Error(`Districts API for ${provinceCode} did not return an array.`);
                            if (data.length > 0) {
                                data.forEach(district => {
                                    const option = document.createElement('option');
                                    option.value = district.code; // Assuming 'code'
                                    option.textContent = district.name; // Assuming 'name'
                                    districtSelect.appendChild(option);
                                });
                                districtSelect.disabled = false;
                            } else {
                                districtSelect.innerHTML = '<option value="">No districts available</option>';
                                districtSelect.disabled = true; // Keep it disabled
                            }
                        })
                        .catch(error => {
                            console.error('Error fetching districts:', error);
                            districtSelect.innerHTML = '<option value="">Error loading districts</option>';
                            districtSelect.disabled = true;
                        });
                }
            });

            // Salary mode change listener
            salaryModeSelect.addEventListener('change', function() {
                if (this.value === 'min' || this.value === 'max') {
                    salaryContainer.style.display = 'block';
                    salaryInput.required = true; // Optional: make salary input required if mode is selected
                } else {
                    salaryContainer.style.display = 'none';
                    salaryInput.value = ''; // Clear salary value when mode is "None"
                    salaryInput.required = false;
                }
            });
        } else {
            console.warn('[DEBUG] One or more filter elements (province, district, salary) not found.');
        }


        // --- Global Helper Functions ---
        window.renderKeywords = function() {
            if (!keywordBox || !keywordsHiddenInput) return; // Guard clause
            Array.from(keywordBox.children).forEach(child => {
                if (child.tagName === 'SPAN') { // Only remove span elements (tags)
                    child.remove();
                }
            });
            keywords.forEach((word, idx) => {
                const tag = document.createElement("span");
                tag.textContent = word;
                tag.style.cssText = `
                    background-color: #eee; color: #333; padding: 4px 8px; margin: 2px;
                    border-radius: 4px; cursor: pointer; display: inline-block;
                    font-size: 0.9em;
                `;
                tag.onclick = () => {
                    keywords.splice(idx, 1);
                    if (keywordInputElement) keywordInputElement.value = word;
                    renderKeywords();
                    if (keywordInputElement) keywordInputElement.focus();
                };
                if (keywordInputElement) keywordBox.insertBefore(tag, keywordInputElement);
            });
            keywordsHiddenInput.value = JSON.stringify(keywords);
            const shouldEnableKeywordButton = keywords.length > 0;
            if(keywordSearchButton) keywordSearchButton.disabled = !shouldEnableKeywordButton;
            logState('After renderKeywords', cvSubmitButton?.disabled, keywordSearchButton?.disabled);
        }

        window.displayFileInfo = function(file, fileInfoId) {
            const targetDiv = document.getElementById(fileInfoId);
            if (!targetDiv) return;
            targetDiv.innerHTML = ''; // Clear previous info
            const fileInfoElement = document.createElement('div'); // Renamed for clarity
            fileInfoElement.className = 'file-info';
            fileInfoElement.innerHTML = `
                <span class="file-icon">📄</span>
                <span>${file.name}</span>
                <span>(${(file.size / 1024 / 1024).toFixed(2)} MB)</span>
                <span style="margin-left: auto; cursor: pointer;"
                      onclick="removeFile(this, 'cvInput')">❌</span>
            `;
            targetDiv.appendChild(fileInfoElement);
            targetDiv.classList.remove('hidden');
        }

        window.removeFile = function(element, inputId) {
            const inputElement = document.getElementById(inputId);
            const fileInfoContainer = element.closest('.file-info')?.parentNode; // Added optional chaining

            element.closest('.file-info')?.remove(); // Added optional chaining

            if (inputElement) {
                inputElement.value = ''; // Clear the file input
            } else {
                console.error(`[DEBUG] Input element not found for ID: ${inputId}`);
            }

            if (inputId === 'cvInput') {
                if (fileInfoContainer && fileInfoContainer.children.length === 0) {
                   clearCvDisplay(); // This also disables the button
                } else if (!fileInfoContainer) { // If the container itself was removed or not found
                    clearCvDisplay();
                }
                if(cvSubmitButton) cvSubmitButton.disabled = true; // Explicitly disable
                logState('After removeFile (CV)', cvSubmitButton.disabled, keywordSearchButton?.disabled);
            }
        }

        window.clearCvDisplay = function() {
            if (cvFileInfoDiv) {
                cvFileInfoDiv.innerHTML = '';
                cvFileInfoDiv.classList.add('hidden');
            }
            if (cvUploadBox) {
                const browseButton = cvUploadBox.querySelector('.browse-button');
                if (browseButton) browseButton.style.display = 'block';
            }
            if(cvSubmitButton) cvSubmitButton.disabled = true;
        }

        if (typeof renderKeywords === 'function') renderKeywords(); // Initial call for keyword form if it exists

    }); // End DOMContentLoaded


    // --- Form Submission Validation ---
    document.getElementById('uploadForm')?.addEventListener('submit', function(event) {
        const cvInputEl = document.getElementById('cvInput');
        const cvFile = cvInputEl?.files[0];

        if (!cvFile) {
            alert('Please select a CV file.');
            event.preventDefault(); return;
        }
        // File type and size checks are already handled by the 'change' event on cvInput,
        // but it's good practice to have them here as a fallback.
        if (cvFile.type !== 'application/pdf') {
            alert('Invalid file type. Only PDF is allowed for CV.');
            event.preventDefault(); return;
        }
        if (cvFile.size > 20 * 1024 * 1024) { // 20MB
            alert('CV file exceeds the 20MB size limit.');
            event.preventDefault(); return;
        }

        // Validate salary if mode is selected but salary is empty/invalid
        const salaryModeEl = document.getElementById('filter_salary_mode');
        const salaryInputEl = document.getElementById('salary');
        if (salaryModeEl && salaryInputEl) {
            const salaryModeValue = salaryModeEl.value;
            const salaryValue = salaryInputEl.value;
            if ((salaryModeValue === 'min' || salaryModeValue === 'max') && (salaryValue.trim() === '' || parseFloat(salaryValue) <= 0)) {
                alert('Please enter a valid positive salary threshold if a salary filter mode is selected.');
                salaryInputEl.focus();
                event.preventDefault(); return;
            }
        }
    });

    // Keyword form validation (remains unchanged)
    document.getElementById('filtersForm')?.addEventListener('submit', function(event) {
        const currentKeywordInput = document.getElementById("keywordInput");
        const keywordsHidden = document.getElementById("keywordsHiddenInput");
        let currentKeywords = [];
        try {
            currentKeywords = JSON.parse(keywordsHidden.value || '[]');
        } catch (e) {
             console.error("Error parsing keywords JSON:", e);
             alert('An error occurred with the keywords. Please try again.');
             event.preventDefault(); return;
        }

        const trimmedInputValue = currentKeywordInput.value.trim();

        if (currentKeywords.length === 0 && trimmedInputValue === '') {
             alert('Please enter at least one keyword.');
             event.preventDefault();
        } else if (trimmedInputValue !== '') {
            // If there's text in input but not yet added (e.g., no double space), add it before submit
            if (!currentKeywords.includes(trimmedInputValue)) {
                currentKeywords.push(trimmedInputValue);
                keywordsHidden.value = JSON.stringify(currentKeywords);
            }
            if (currentKeywords.length === 0) { // Re-check after attempting to add
                alert('Please enter at least one keyword.');
                event.preventDefault();
            }
        }
    });

</script>
@endsection