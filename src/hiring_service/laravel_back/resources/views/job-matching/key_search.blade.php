@extends('layouts.app')

@section('content')
    <style>
        h1 {
            text-align: center;
            font-family: 'Nunito', sans-serif;
            font-size: 24px;
            color: #008080; /* Teal color */
            margin-bottom: 30px; /* Added margin */
        }

        .dataframe {
          border-collapse: collapse;
          margin: 25px auto; /* Center the table */
          font-size: 0.9em;
          font-family: 'Nunito', sans-serif;
          min-width: 400px;
          max-width: 90%; /* Responsive width */
          box-shadow: 0 0 20px rgba(0, 0, 0, 0.15);
          width: auto; /* Adjust based on content */
        }

        .dataframe thead tr {
            background-color: #009879; /* Standard green */
            color: #ffffff;
            text-align: left;
            font-weight: bold; /* Added boldness */
        }

        .dataframe th, .dataframe td {
            padding: 12px 15px;
            border: 1px solid #dddddd; /* Add borders to cells */
        }

        .dataframe tbody tr {
            border-bottom: 1px solid #dddddd;
        }

        .dataframe tbody tr:nth-of-type(even) {
            background-color: #f3f3f3;
        }

        .dataframe tbody tr:last-of-type {
            border-bottom: 2px solid #009879; /* Match header color */
        }

        .dataframe tbody tr:hover { /* Add hover effect */
            background-color: #f1f1f1;
        }

        /* Form Styling */
        #filtersForm {
            display: flex;
            flex-direction: column; /* Stack elements vertically */
            align-items: center; /* Center items horizontally */
            gap: 15px; /* Space between elements */
            max-width: 700px; /* Limit form width */
            margin: 30px auto 50px; /* Center form and add margins */
            padding: 25px;
            background-color: #ffffff;
            border: 1px solid #ddd;
            border-radius: 8px; /* Softer corners */
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1); /* Subtle shadow */
        }

        #filtersForm p {
            color: gray;
            font-size: 0.9rem;
            font-family: 'Nunito', sans-serif;
            margin-bottom: 5px; /* Space below paragraph */
            text-align: center; /* Center text */
            width: 100%; /* Take full width */
        }

        /* Keyword Input Box */
        #keywordBox {
            display: flex;
            flex-wrap: wrap;
            align-items: center; /* Align tags and input vertically */
            border: 1px solid #ccc;
            padding: 8px; /* Increased padding */
            border-radius: 4px;
            min-height: 45px; /* Ensure enough height */
            width: 100%; /* Take full width */
            box-sizing: border-box; /* Include padding/border in width */
            cursor: text; /* Indicate it's editable */
        }

        #keywordInput {
            border: none;
            outline: none;
            flex-grow: 1; /* Take remaining space */
            padding: 6px; /* Padding inside input */
            font-family: 'Nunito', sans-serif;
            font-size: 14px;
            min-width: 150px; /* Ensure minimum typing space */
        }

        /* Keyword Tag Styling */
        .keyword-tag {
            background-color: #e0e0e0; /* Lighter gray */
            color: #333; /* Darker text */
            padding: 5px 10px; /* Adjust padding */
            margin: 3px; /* Spacing around tags */
            border-radius: 15px; /* Pill shape */
            cursor: pointer;
            display: inline-flex; /* Use flex for alignment */
            align-items: center;
            font-size: 13px; /* Slightly smaller font */
            font-family: 'Nunito', sans-serif;
        }

        .keyword-tag:hover {
            background-color: #c7c7c7; /* Darker on hover */
        }

        /* Form Actions/Button */
        .form-actions { /* No longer needed if button is directly in form */
            /* flex: 1 1 100%; */
            /* text-align: center; */
        }

        #filtersForm button {
            padding: 10px 25px; /* More padding */
            background-color: #009879;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 16px;
            font-family: 'Nunito', sans-serif;
            transition: background-color 0.2s ease; /* Smooth transition */
            margin-top: 10px; /* Space above button */
        }

        #filtersForm button:hover {
            background-color: #007f65; /* Darker green on hover */
        }

        /* Result Container */
        #resultContainer {
            margin: 0 auto; /* Center results */
            max-width: 90%; /* Match table width */
        }

    </style>

    <h1>Our top recommended jobs for you</h1>

    {{-- Search Form --}}
    <form id="filtersForm" method="POST" action="{{ route('fastjob.search') }}">
        @csrf
        <p>Don't like what you saw? Try searching different keywords.</p>

        {{-- Keyword input area --}}
        <div id="keywordBox" onclick="document.getElementById('keywordInput').focus();"> {{-- Focus input on box click --}}
            {{-- Tags will be inserted here by JS --}}
            <input
                type="text"
                id="keywordInput"
                placeholder="Type keywords (double-space or Enter to add)"
                style="border: none; outline: none; flex-grow: 1; padding: 6px;" {{-- Use flex-grow --}}
                autocomplete="off"
            >
        </div>

        {{-- Hidden input to store keywords as JSON --}}
        <input type="hidden" name="keywords" id="keywordsHiddenInput">

        {{-- Submit Button --}}
        <button type="submit">Search</button>
    </form>

    {{-- Results Area --}}
    <div id="resultContainer">
        @isset($results)
            {!! $results !!} <!-- Render results directly (Ensure backend sanitizes!) -->
        @endisset
    </div>

    <script>
        const form = document.getElementById("filtersForm");
        const input = document.getElementById("keywordInput");
        const keywordBox = document.getElementById("keywordBox");
        const hiddenInput = document.getElementById("keywordsHiddenInput");

        let keywords = []; // Array to store keyword strings

        // Function to add a keyword term
        function addKeyword(term) {
            const word = term.trim();
            // Only add if it's not empty and not already included
            if (word && !keywords.includes(word)) {
                keywords.push(word);
                renderKeywords(); // Update the display and hidden input
            }
            input.value = ""; // Clear the input field
        }

        // Function to remove a keyword by index
        function removeKeyword(index) {
            keywords.splice(index, 1); // Remove keyword from array
            renderKeywords(); // Update the display and hidden input
            input.focus(); // Keep focus on input
        }

        // Function to re-render the keyword tags in the keywordBox
        function renderKeywords() {
            // Clear existing tags, but keep the input field
            keywordBox.querySelectorAll('.keyword-tag').forEach(tag => tag.remove());

            // Create and append tags for each keyword
            keywords.forEach((word, idx) => {
                const tag = document.createElement("span");
                tag.textContent = word;
                tag.classList.add('keyword-tag'); // Add class for styling

                // Add a remove button (optional, but good UX)
                const removeBtn = document.createElement("span");
                removeBtn.textContent = ' \u00D7'; // Multiplication sign (X)
                removeBtn.style.marginLeft = '5px';
                removeBtn.style.cursor = 'pointer';
                removeBtn.onclick = (e) => {
                    e.stopPropagation(); // Prevent click propagating to the keywordBox
                    removeKeyword(idx);
                };
                tag.appendChild(removeBtn);

                // Clicking the tag itself can remove it (or edit, as per original)
                // For simplicity, let's just use the X button
                /*
                tag.onclick = () => {
                    // Option 1: Edit (like original)
                    input.value = word;
                    removeKeyword(idx); // remove from list before editing
                    // Option 2: Just remove (simpler with X button)
                    // removeKeyword(idx);
                };
                */

                // Insert the tag before the input field
                keywordBox.insertBefore(tag, input);
            });

            // Update the hidden input with the JSON string of keywords
            hiddenInput.value = JSON.stringify(keywords);
        }

        // --- Event Listeners ---

        // Listen for keydown events on the keyword input field
        input.addEventListener("keydown", function(e) {
            const currentInputValue = input.value;
            const trimmedValue = currentInputValue.trim();

            // 1. Double Space: Add keyword if space is pressed and previous char was also space
            if (e.key === " " && currentInputValue.endsWith(" ") && trimmedValue) {
                 e.preventDefault(); // Prevent adding the second space character
                 addKeyword(trimmedValue);
            }
            // 2. Enter Key: Add current input as keyword (if any) and submit form
            else if (e.key === "Enter") {
                e.preventDefault(); // IMPORTANT: Prevent default form submission for now
                if (trimmedValue) {
                    addKeyword(trimmedValue); // Add the keyword first
                }
                // Check if there are keywords before submitting (optional)
                if (keywords.length > 0 || trimmedValue) { // Allow submitting even if only current input exists and will be added
                     form.submit(); // Manually submit the form
                } else {
                    // Maybe provide feedback if trying to submit empty?
                    console.log("No keywords to search for.");
                }
            }
            // 3. Backspace Key: Remove the last tag if input is empty
            else if (e.key === "Backspace" && currentInputValue === "" && keywords.length > 0) {
                e.preventDefault(); // Prevent potential browser back navigation
                // Option 1: Just remove the last tag
                // removeKeyword(keywords.length - 1);

                // Option 2: Edit last tag (put it back in input)
                input.value = keywords.pop(); // Remove last from array and put in input
                renderKeywords(); // Update display (removes the tag)
            }
        });

        // Optional: Re-render if keywords somehow get out of sync (e.g., browser back button)
        // This might be needed if using browser history manipulation
        // window.addEventListener('pageshow', () => {
        //    try {
        //        keywords = JSON.parse(hiddenInput.value || '[]');
        //    } catch (e) {
        //        keywords = [];
        //    }
        //    renderKeywords();
        // });

        // Initial render in case the page was reloaded with values (less common with POST)
        try {
            keywords = JSON.parse(hiddenInput.value || '[]');
        } catch (e) {
            keywords = []; // Start fresh if JSON is invalid
        }
        renderKeywords();

        // Auto-focus the input on load
        input.focus();

    </script>
@endsection