package com.example.myapplication;

import android.os.Bundle;
import android.os.Handler;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import androidx.annotation.NonNull;
import androidx.fragment.app.Fragment;
import com.example.myapplication.databinding.FragmentFirstBinding;

public class FirstFragment extends Fragment {

    private FragmentFirstBinding binding;
    private MainActivity mainActivity;

    @Override
    public View onCreateView(
            LayoutInflater inflater, ViewGroup container,
            Bundle savedInstanceState
    ) {
        binding = FragmentFirstBinding.inflate(inflater, container, false);
        return binding.getRoot();
    }



        // Start vibration when the first button is clicked
        @Override
        public void onViewCreated(@NonNull View view, Bundle savedInstanceState) {
            super.onViewCreated(view, savedInstanceState);

            // Get the main activity to access the vibration methods
            mainActivity = (MainActivity) getActivity();

            // Start vibration when the first button is clicked
            binding.buttonFirst.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View view) {
                    if (mainActivity != null) {
                        // Start vibration immediately
                        mainActivity.startVibration(mainActivity.getInputText());

                        // Delay the audio generation by 2.5 milliseconds
                        new Handler().postDelayed(new Runnable() {
                            @Override
                            public void run() {

//                                mainActivity.generateAudio();
                            }
                        }, 3);
                    }
                }
            });

            // Uncomment this section if you plan to handle the second button functionality
//        binding.buttonSecond.setOnClickListener(new View.OnClickListener() {
//            @Override
//            public void onClick(View view) {
//                if (mainActivity != null) {
//                    mainActivity.stopVibration();
//                }
//            }
//        });
        }

    @Override
    public void onDestroyView() {
        super.onDestroyView();
        binding = null;
    }
}
