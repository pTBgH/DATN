@extends('layouts.app')

@section('content')
    <style>
        h1 {
            text-align: center;
            font-family: 'Nunito', sans-serif;
            font-size: 24px;
            color: #008080;
        }

        .dataframe {
          border-collapse: collapse;
          margin: 25px 0;
          font-size: 0.9em;
          font-family: 'Nunito', sans-serif;
          min-width: 400px;
          box-shadow: 0 0 20px rgba(0, 0, 0, 0.15);
          width: 80%;
          margin: 0 auto;
        }

        .dataframe thead tr {
            background-color: #009879;
            color: #ffffff;
            text-align: left;
        }

        .dataframe th, .dataframe td {
            padding: 12px 15px;
        }

        .dataframe tbody tr {
            border-bottom: 1px solid #dddddd;
        }

        .dataframe tbody tr:nth-of-type(even) {
            background-color: #f3f3f3;
        }

        .dataframe tbody tr:last-of-type {
            border-bottom: 2px solid #009879;
        }

        form {
            display: flex;
            flex-wrap: wrap;
            gap: 20px;
            max-width: 80%;
            margin: 0 auto 50px;
            padding: 20px;
            background-color: #ffffff;
            border: 1px solid #ddd;
            border-radius: 5px;
        }
        .form-group {
            flex: 1 1 200px;
            display: flex;
            flex-direction: column;
        }
        label {
            font-weight: bold;
            margin-bottom: 5px;
            font-family: 'Nunito', sans-serif;
        }
        input, select {
            padding: 8px;
            border: 1px solid #ccc;
            border-radius: 4px;
            font-size: 14px;
            width: 100%;
            box-sizing: border-box;
            font-family: 'Nunito', sans-serif;
        }
        .form-actions {
            flex: 1 1 100%;
            text-align: center;
            font-family: 'Nunito', sans-serif;
        }
        button {
            padding: 10px 20px;
            background-color: #009879;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
            font-size: 16px;
            font-family: 'Nunito', sans-serif;
        }
        button:hover {
            background-color: #007f65;
        }
        .salary-range {
            display: flex;
            gap: 10px;
        }
        .salary-range input {
            flex: 1;
        }
    </style>

    <h1 class="text-center">Our top recommended jobs for you</h1>


    <div id="resultContainer">
        @isset($results)
            {!! $results !!} <!-- Render results directly -->
        @endisset
    </div>

    <div class="form-actions">
        <a href="/" style="text-decoration: none;">
            <button type="button">Go back</button>
        </a>
    </div>
    
@endsection