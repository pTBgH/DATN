<table class="dataframe">
    <thead>
        <tr>
            <th>Title</th>
            <th>Company Name</th>
            <th>City</th>
            <th>District</th>
            <th>Salary Min</th>
            <th>Experience Years</th>
            <th>Deadline</th>
            <th>Contract Type</th>
            <th>Date since posted</th>
            
        </tr>
    </thead>
    <tbody>
        @forelse ($jobs as $job)
            <tr>
                <td>{{ $job['title'] }}</td>
                <td>{{ $job['company_name'] }}</td>
                <td>{{ $job['city_name'] }}</td>
                <td>{{ $job['district_name'] }}</td>
                <td>{{ $job['salary_min'] }}</td>
                <td>{{ $job['experience_years'] }}</td>
                <td>{{ $job['deadline'] }}</td>
                <td>{{ $job['job_type'] }}</td>
                <td>{{ $job['days_since_open']}}</td>
            </tr>
        @empty
            <tr>
                <td colspan="6" style="text-align: center;">No jobs found.</td>
            </tr>
        @endforelse
    </tbody>
</table>
